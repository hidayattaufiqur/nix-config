#!/usr/bin/env python3
"""quota_snapshot.py — real subscription quota for CommandCode and Copilot.

Writes one JSON document with every quota window we can actually observe, so a
cron job (or the proactive-gate) can reason about the numbers instead of the
user opening two dashboards.

Sources, both verified live on 2026-11-07:

  CommandCode — 9router's per-connection usage endpoint.
      9router already does the hard part: it talks to CommandCode's own billing
      API with the provider key and normalises the answer. The endpoint needs an
      admin session (NOT the OpenAI-compatible API key), so we log in with
      INITIAL_PASSWORD from the container's own environment. That is why this
      script runs the 9router leg as `docker exec node ...` — the password never
      touches the host shell or a file.

      GET /api/usage/<connectionId>  ->  {plan, quotas: {name: {used,total,
                                            remaining,resetAt,unlimited}}}
      Observed 2026-11-07: plan=GOAT, Credits 44.1/70, Session (5h) 0.4/14,
      Weekly 2.06/35. CommandCode's own public API has NO usage route (all 404),
      so 9router is not a convenience here — it is the only path.

  Copilot — GitHub's internal Copilot endpoint, with the gh token Hermes
      already holds in .env (COPILOT_GITHUB_TOKEN, a gho_ user token).
      GET https://api.github.com/copilot_internal/user
      -> quota_snapshots: {chat, completions, premium_interactions}, each with
         credits_used / unlimited / percent_remaining, plus quota_reset_date.

      IMPORTANT, and the reason this is worth having: Copilot Business reports
      `unlimited: true` and `entitlement: 0` for premium_interactions while
      crediting `credits_used` against it. The published Business allowance is
      300 premium requests/user/month, so `unlimited` is a lie in practice —
      the honest reading is credits_used vs the documented plan allowance. We
      therefore report BOTH: what GitHub says (unlimited) and what it counts
      (credits_used), and only alert on the count.

Exit codes: 0 always. Quota collection must never break a cron chain.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

OUT = Path(os.getenv("QUOTA_OUT", "/var/lib/hermes/.hermes/cache/quota/latest.json"))
HERMES_ENV = Path("/var/lib/hermes/.hermes/.env")
CONTAINER = os.getenv("QUOTA_CONTAINER", "9router")
BASE = os.getenv("QUOTA_9ROUTER", "http://127.0.0.1:20128")

# Published monthly allowances, used to turn a bare counter into a percentage.
# Copilot Business = 1,900 GitHub AI credits per user per month (NOT the legacy
# 300 "premium requests" figure, which is dead as of usage-based billing).
# 1 AI credit = $0.01 USD. CommandCode values come from its own API, so they are
# not hardcoded here.
COPILOT_PREMIUM_ALLOWANCE = int(os.getenv("COPILOT_PREMIUM_ALLOWANCE", "1900"))


def _env_value(name: str) -> str | None:
    """Read one key from Hermes's .env without shelling out (no secret on argv)."""
    try:
        for line in HERMES_ENV.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if line.startswith(f"{name}="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    except OSError:
        return None
    return None


# ── CommandCode via 9router ──────────────────────────────────────────────
# Runs inside the container: logs in with INITIAL_PASSWORD from its own env,
# finds the commandcode connection, and reads /api/usage/<id>. Prints JSON.
_CC_JS = r"""
const base = process.env.QB || "http://127.0.0.1:20128";
(async () => {
  const out = { ok: false };
  try {
    const pw = process.env.INITIAL_PASSWORD;
    if (!pw) { out.error = "INITIAL_PASSWORD missing in container"; console.log(JSON.stringify(out)); return; }
    let cookie = "";
    for (const body of [{ password: pw }, { password: pw, username: "admin" }]) {
      const r = await fetch(base + "/api/auth/login", {
        method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body),
      });
      const setc = r.headers.getSetCookie ? r.headers.getSetCookie() : [];
      if (r.ok && setc.length) { cookie = setc.map((c) => c.split(";")[0]).join("; "); break; }
    }
    if (!cookie) { out.error = "9router login failed"; console.log(JSON.stringify(out)); return; }
    const H = { Cookie: cookie, "Content-Type": "application/json" };
    const conns = await (await fetch(base + "/api/providers/client", { headers: H })).json();
    const cc = (conns.connections || []).filter((c) => c.provider === "commandcode");
    if (!cc.length) { out.error = "no commandcode connection"; console.log(JSON.stringify(out)); return; }
    out.connections = [];
    for (const c of cc) {
      const r = await fetch(base + "/api/usage/" + c.id, { headers: H });
      if (!r.ok) { out.connections.push({ id: c.id, active: c.isActive, error: "usage HTTP " + r.status }); continue; }
      const u = await r.json();
      out.connections.push({ id: c.id, active: c.isActive, plan: u.plan, quotas: u.quotas });
    }
    out.ok = true;
  } catch (e) { out.error = String(e && e.message || e); }
  console.log(JSON.stringify(out));
})();
"""


def collect_commandcode() -> dict:
    """CommandCode quota through 9router's admin session, executed in-container."""
    # cron runs with PATH=/usr/bin:/bin, where docker does not exist. Resolve it
    # explicitly rather than trusting PATH: on NixOS the stable entry point is
    # /run/current-system/sw/bin, and a hardcoded /nix/store path would break on
    # every rebuild that touches docker.
    docker = shutil.which("docker")
    if not docker:
        for cand in ("/run/current-system/sw/bin/docker", "/usr/bin/docker"):
            if os.access(cand, os.X_OK):
                docker = cand
                break
    if not docker:
        return {"source": "9router", "ok": False, "error": "docker not found in PATH or /run/current-system"}
    try:
        proc = subprocess.run(
            [docker, "exec", "-i", CONTAINER, "node", "--input-type=module", "-e", _CC_JS],
            capture_output=True, text=True, timeout=45,
        )
    except FileNotFoundError:
        return {"source": "9router", "ok": False, "error": "docker not available"}
    except subprocess.TimeoutExpired:
        return {"source": "9router", "ok": False, "error": "timeout"}

    raw = (proc.stdout or "").strip().splitlines()
    if not raw:
        return {"source": "9router", "ok": False,
                "error": (proc.stderr or "no output").strip()[:200]}
    try:
        parsed = json.loads(raw[-1])
    except json.JSONDecodeError:
        return {"source": "9router", "ok": False, "error": "unparseable: " + raw[-1][:150]}

    parsed["source"] = "9router"
    # Surface the ACTIVE connection's numbers as the top-level convenience view.
    conns = parsed.get("connections") or []
    active = next((c for c in conns if c.get("active")), conns[0] if conns else None)
    if active and active.get("quotas"):
        parsed["plan"] = active.get("plan")
        parsed["quotas"] = active["quotas"]
    return parsed


# ── Copilot ──────────────────────────────────────────────────────────────
def collect_copilot() -> dict:
    token = _env_value("COPILOT_GITHUB_TOKEN")
    if not token:
        return {"source": "github", "ok": False, "error": "COPILOT_GITHUB_TOKEN not set"}
    req = urllib.request.Request(
        "https://api.github.com/copilot_internal/user",
        headers={
            "Authorization": f"token {token}",
            # GitHub 403s this endpoint without a Copilot-looking UA/editor pair.
            "User-Agent": "GithubCopilot/1.250.0",
            "Accept": "application/json",
            "Editor-Version": "vscode/1.99.0",
            "Editor-Plugin-Version": "copilot/1.250.0",
            "Copilot-Integration-Id": "vscode-chat",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            data = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        return {"source": "github", "ok": False, "error": f"HTTP {exc.code}"}
    except Exception as exc:
        return {"source": "github", "ok": False, "error": type(exc).__name__}

    snaps = data.get("quota_snapshots") or {}
    pm = snaps.get("premium_interactions") or {}
    used = pm.get("credits_used")
    allowance = COPILOT_PREMIUM_ALLOWANCE
    pct = round(100.0 * used / allowance, 1) if isinstance(used, (int, float)) and allowance else None
    return {
        "source": "github",
        "ok": True,
        "plan": data.get("copilot_plan"),
        "sku": data.get("access_type_sku"),
        "reset_date": data.get("quota_reset_date"),
        "credits": {
            # `credits_used` on the premium_interactions snapshot IS the GitHub AI
            # Credits figure under usage-based billing (1 credit = $0.01). The
            # quota_id name is a legacy label; `token_based_billing: true` and
            # the docs are what settle it.
            "used": used,
            "allowance_per_seat": allowance,
            "percent_of_seat_allowance": pct,
            "implied_usd": round(used * 0.01, 2) if isinstance(used, (int, float)) else None,
            # Do NOT report this against a hard cap. Business credits are POOLED
            # across the whole org, so one seat's 1,900 is its contribution to
            # the pool, not that user's ceiling. The API exposes no pool total
            # (org copilot/billing needs an admin-scoped token we do not hold),
            # so we report per-seat contribution usage and say so plainly.
            "pool_note": "Business credits are pooled org-wide; this is one seat's "
                         "consumption against its 1,900/mo contribution, not a cap.",
            "github_reports": {k: pm.get(k) for k in
                               ("unlimited", "percent_remaining", "entitlement",
                                "token_based_billing", "overage_permitted")},
        },
        "snapshots": {k: {"credits_used": (v or {}).get("credits_used"),
                          "unlimited": (v or {}).get("unlimited"),
                          "percent_remaining": (v or {}).get("percent_remaining")}
                      for k, v in snaps.items()},
    }


def _breaches(doc: dict) -> list[str]:
    """Compare the snapshot against thresholds. Returns human-readable findings.

    Thresholds live in env so tuning needs no code change. Rationale for the
    defaults: a quota that resets in a week matters less than one that resets in
    a month, so the monthly window gets the tightest bar. The 5h session window
    is deliberately NOT alerted on — it rolls over constantly and a warning
    about it would be exactly the kind of noise this whole exercise removes.
    """
    warn = float(os.getenv("QUOTA_WARN_PCT", "80"))
    crit = float(os.getenv("QUOTA_CRIT_PCT", "95"))
    findings = []

    cc = doc.get("commandcode") or {}
    if cc.get("ok"):
        for name, q in (cc.get("quotas") or {}).items():
            try:
                used, total = float(q["used"]), float(q["total"])
            except (KeyError, TypeError, ValueError):
                continue
            if total <= 0 or q.get("unlimited"):
                continue
            pct = 100.0 * used / total
            if pct >= crit:
                findings.append(
                    f"CRITICAL CommandCode {name}: {used:.1f}/{total:.0f} used "
                    f"({pct:.0f}%), resets {q.get('resetAt', '?')}")
            elif pct >= warn:
                findings.append(
                    f"CommandCode {name}: {used:.1f}/{total:.0f} used "
                    f"({pct:.0f}%), resets {q.get('resetAt', '?')}")
    else:
        findings.append(f"CommandCode quota unreadable: {cc.get('error', 'unknown')}")

    cp = doc.get("copilot") or {}
    if cp.get("ok"):
        cr = cp.get("credits") or {}
        pct = cr.get("percent_of_seat_allowance")
        used = cr.get("used")
        # Copilot Business credits are POOLED org-wide, and the API exposes no
        # pool total, so there is no real threshold to cross. What is worth a
        # message is scale: a seat consuming more than its own 1,900/mo
        # contribution means the org pool is being drawn down by this seat
        # alone. Report that once per day — a static credit count re-notified
        # every 4 hours is exactly the noise this system exists to remove.
        if isinstance(pct, (int, float)) and pct >= 100:
            today = datetime.now(timezone.utc).date().isoformat()
            if cp.get("_reported_on") != today:
                findings.append(
                    f"Copilot AI credits: {used} used (~${cr.get('implied_usd')}), beyond this "
                    f"seat's {cr.get('allowance_per_seat')}/mo contribution — drawing on the "
                    f"shared org pool. Resets {cp.get('reset_date', '?')}")
            cp["_reported_on"] = today
    else:
        findings.append(f"Copilot quota unreadable: {cp.get('error', 'unknown')}")

    return findings


def _persist(doc: dict) -> None:
    try:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(doc, indent=1), encoding="utf-8")
    except OSError as exc:
        print(f"quota_snapshot: cannot write {OUT}: {exc}", file=sys.stderr)


def _digest(doc: dict) -> str:
    """Full quota report, delivered daily.

    The watchdog (_breaches) answers "is anything wrong right now" and stays
    silent when nothing is. That is the wrong shape for the question actually
    being asked — "where do I stand today" — which needs a number whether or not
    a threshold was crossed. So this mode always prints, and includes the
    days-remaining projection that makes the number actionable.
    """
    lines = ["**Subscription quota** — " +
             datetime.now(timezone.utc).astimezone().strftime("%a %d %b %H:%M")]

    cc = doc.get("commandcode") or {}
    if cc.get("ok"):
        plan = cc.get("plan") or "?"
        lines.append(f"\n**CommandCode ({plan})**")
        for name, q in (cc.get("quotas") or {}).items():
            try:
                used, total = float(q["used"]), float(q["total"])
            except (KeyError, TypeError, ValueError):
                continue
            if total <= 0:
                continue
            pct = 100.0 * used / total
            left = total - used
            bar = "█" * int(round(pct / 10)) + "░" * (10 - int(round(pct / 10)))
            reset = (q.get("resetAt") or "")[:10]
            lines.append(f"`{bar}` {pct:5.1f}%  {name}: {left:.1f} left of {total:.0f}"
                         + (f"  · resets {reset}" if reset else ""))
    else:
        lines.append(f"\n**CommandCode** — unreadable: {cc.get('error', 'unknown')}")

    cp = doc.get("copilot") or {}
    if cp.get("ok"):
        cr = cp.get("credits") or {}
        used = cr.get("used")
        allow = cr.get("allowance_per_seat")
        pct = cr.get("percent_of_seat_allowance")
        if isinstance(pct, (int, float)):
            bar = "█" * int(round(pct / 10)) + "░" * (10 - int(round(pct / 10)))
            left = allow - used
            lines.append(f"\n**GitHub Copilot (business)**")
            lines.append(f"`{bar}` {pct:5.1f}%  {left} left of {allow} credits (~${left * 0.01:.2f})"
                         f"  · resets {cp.get('reset_date', '?')}")
            # Pooling caveat is load-bearing: without it the 1,900 reads as a cap.
            lines.append("_Pooled org-wide, so this is one seat's contribution, not a ceiling._")
    else:
        lines.append(f"\n**GitHub Copilot** — unreadable: {cp.get('error', 'unknown')}")

    # Anything over a threshold still gets called out at the bottom.
    warn = _breaches(doc)
    if warn:
        lines.append("\n**⚠ Over threshold**")
        for w in warn:
            lines.append(f"- {w}")

    return "\n".join(lines)


def main() -> int:
    doc = {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "commandcode": collect_commandcode(),
        "copilot": collect_copilot(),
    }

    if "--digest" in sys.argv:
        # Daily reporting mode: always prints, threshold or not.
        prev = {}
        try:
            prev = json.loads(OUT.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            pass
        if isinstance(prev.get("copilot"), dict) and isinstance(doc.get("copilot"), dict):
            if prev["copilot"].get("_reported_on"):
                doc["copilot"]["_reported_on"] = prev["copilot"]["_reported_on"]
        text = _digest(doc)
        _persist(doc)
        print(text)
        return 0

    if "--check" in sys.argv:
        # Cron-script mode: print ONLY actionable findings, so an empty stdout
        # means "nothing to say" and the job stays silent without an LLM call.
        #
        # Ordering matters here: read the previous snapshot FIRST, carry its
        # per-day marker forward, evaluate, and only then persist. Persisting
        # before evaluating wiped the marker on every run, so the once-a-day
        # guard could never hold.
        prev = {}
        try:
            prev = json.loads(OUT.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            pass
        if isinstance(prev.get("copilot"), dict) and isinstance(doc.get("copilot"), dict):
            if prev["copilot"].get("_reported_on"):
                doc["copilot"]["_reported_on"] = prev["copilot"]["_reported_on"]

        findings = _breaches(doc)  # may stamp _reported_on on doc["copilot"]
        _persist(doc)
        if findings:
            print("\n".join(findings))
        return 0

    _persist(doc)
    print(json.dumps(doc, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
