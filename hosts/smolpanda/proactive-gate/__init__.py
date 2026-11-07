"""proactive-gate plugin — cron output must earn the interruption.

The problem this solves
-----------------------
Scheduled jobs are dumb broadcasters: every tick that produces text delivers it
to the user's chat, whether or not anything actually changed. Over a week that
trains the user to ignore the channel, which is exactly backwards - a proactive
assistant is only useful if its interruptions are rare and always worth reading.

Robin Syihab's "Proactive Agent" writeup names the three hard parts:
**Relevancy**, **Materiality**, and **Economy**. This plugin implements them for
the one lane where they bite hardest and cost least to fix: cron delivery.

Design
------
  * ``transform_llm_output`` hook. Hermes fires it once per turn with the final
    response text; returning a non-empty string replaces that response. The
    cron scheduler then applies its own ``[SILENT]`` suppression AFTER this
    hook, so rewriting the response to ``[SILENT]`` suppresses delivery while
    still saving the output locally for audit. That is the whole trick: no
    scheduler patch, no fork, reversible by removing one directory.

  * Only cron turns are gated. ``platform`` is forwarded by the turn finalizer,
    so an interactive Discord/CLI reply is never inspected. Interactive turns
    are already a response to a human asking something.

  * Two-stage decision, cheapest first:
      1. Deterministic prescreen - empty output, too-short output, an explicit
         ``[SILENT]`` already present, or a known low-signal report shape
         ("no new results", "0 findings") is decided for free.
      2. One jev call (CommandCode ``typesafe/jev``) with four ``noul``
         questions. Measured ~400 input / ~70 output tokens, ~1-2s. Jev is a
         decision model: it returns calibrated probabilities, not prose, which
         is why it is affordable on every tick.
      3. Only ambiguous verdicts escalate to GLM-5.3-Flash for the tie-break
         and a human-readable reason. Measured 1.2-1.5s, $0.15/M input.

  Economy: the common cases cost one jev call (~470 tok). The escalation path
  is rare by construction; ``--dry-run`` mode proves that before enforcement.

  * Fails OPEN. If jev and GLM are both unreachable the report is delivered.
    A missed interruption is recoverable; a silently swallowed report is not.
    This is the opposite of jev-gate's fail-closed default, deliberately: the
    cost asymmetry is reversed (there, running a bad command burns a session;
    here, dropping a good report hides work).

  * Every verdict is appended to ``decisions.jsonl`` under the plugin dir, so
    thresholds can be tuned from real data instead of intuition. That file is
    the whole point of the design: the numbers, not the LLM, decide whether the
    bands are right.

Tuning
------
Everything lives in env vars so a nix-config change is not needed to tune:

    PROACTIVE_GATE_MODE             off | dry-run | enforce   (default: dry-run)
    PROACTIVE_GATE_DELIVER_MATERIAL float (default 0.65)  -> deliver outright
    PROACTIVE_GATE_DELIVER_RELEVANT float (default 0.50)
    PROACTIVE_GATE_ACTION_OVERRIDE  float (default 0.70)  -> action alone delivers
    PROACTIVE_GATE_DROP_MATERIAL    float (default 0.30)  -> suppress on [SILENT]
    PROACTIVE_GATE_TIMEOUT_S        float (default 12)
    PROACTIVE_GATE_ESCALATE         bool  (default 1)     -> use GLM tie-break
    PROACTIVE_GATE_MODEL            str   (default z-ai/glm-5.3-flash)

Shipping default is ``dry-run`` on purpose: it records verdicts and changes
nothing. Flip to ``enforce`` only after the log shows the bands are sane.
"""

from __future__ import annotations

import json
import logging
import os
import re
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

logger = logging.getLogger(__name__)

PLUGIN_DIR = Path(__file__).resolve().parent
DECISION_LOG = PLUGIN_DIR / "decisions.jsonl"
MAX_REPORTS = 20          # entries parsed per hour, to bound its own cost

# ── tunables ────────────────────────────────────────────────────────────
MODE = os.getenv("PROACTIVE_GATE_MODE", "dry-run").strip().lower()
DELIVER_MATERIAL = float(os.getenv("PROACTIVE_GATE_DELIVER_MATERIAL", "0.65"))
DELIVER_RELEVANT = float(os.getenv("PROACTIVE_GATE_DELIVER_RELEVANT", "0.50"))
ACTION_OVERRIDE = float(os.getenv("PROACTIVE_GATE_ACTION_OVERRIDE", "0.70"))
DROP_MATERIAL = float(os.getenv("PROACTIVE_GATE_DROP_MATERIAL", "0.30"))
TIMEOUT_S = float(os.getenv("PROACTIVE_GATE_TIMEOUT_S", "12"))
ESCALATE = os.getenv("PROACTIVE_GATE_ESCALATE", "1") != "0"
FILTER_MODEL = os.getenv("PROACTIVE_GATE_MODEL", "z-ai/glm-5.3-flash")
MAX_CHARS = int(os.getenv("PROACTIVE_GATE_MAX_CHARS", "6000"))

COMMANDCODE_CHAT = "https://api.commandcode.ai/provider/v1/chat/completions"
COMMANDCODE_S1 = "https://api.commandcode.ai/provider/v1/systemone"

USER_AGENT = "curl/8.0"  # Cloudflare in front of these endpoints 403s python-urllib

# Report shapes that are empirically never worth an interruption. Kept narrow
# and anchored to the *beginning* of the text, because a report that merely
# mentions "no new results" mid-paragraph is usually a real summary.
LOW_SIGNAL_RES = [
    re.compile(r"^\s*(?:no (?:new )?(?:results|changes|updates|publications|items|data)\b)", re.I),
    re.compile(r"^\s*(?:nothing (?:new|to report|changed)\b)", re.I),
    re.compile(r"^\s*(?:0 (?:results|findings|items|rows|matches)\b)", re.I),
    re.compile(r"^\s*(?:all clear\b|no action (?:needed|required)\b)", re.I),
]

# A report has to contain at least one of these to be actionable. Absence is a
# signal, not a veto: the model still decides, this only feeds the prescreen.
ACTION_HINT_RE = re.compile(
    r"\b(?:deadline|due|expire[sd]?|overdue|before|cap(?:ped|ping)?|exceeds?|exceeded"
    r"|fail(?:ed|ure|ing)?|error|blocked|blocker|risk|warn(?:ing)?|critical|urgent"
    r"|changed|increased|decreased|dropped|below|above|quota|credit|suspend(?:ed)?"
    r"|missing|mismatch|conflict|revert(?:ed)?|rollback|approval|sign[- ]?off)\b",
    re.I,
)


# ── decision log ────────────────────────────────────────────────────────
def _log(entry: dict) -> None:
    """Append one verdict. Best-effort: never let logging break a delivery."""
    try:
        entry = {"ts": datetime.now(timezone.utc).isoformat(timespec="seconds"), **entry}
        with DECISION_LOG.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception as exc:  # pragma: no cover - disk full / perms
        logger.warning("proactive-gate: could not write decision log: %s", exc)


# ── prescreen ───────────────────────────────────────────────────────────
def _prescreen(text: str) -> tuple[str, str] | None:
    """Decide the obvious cases for free. Returns (action, reason) or None."""
    stripped = text.strip()
    if not stripped:
        return "drop", "empty output"
    if "[SILENT]" in stripped[:200]:
        # The job already decided it had nothing to say. Leave it alone so the
        # scheduler's own suppression does the work.
        return "pass", "job already silent"
    if len(stripped) < 40:
        return "drop", f"too short to be material ({len(stripped)} chars)"
    for rx in LOW_SIGNAL_RES:
        if rx.match(stripped):
            return "drop", f"low-signal shape: {rx.pattern[:40]}"
    return None


# ── jev: four probabilities, ~470 tokens ────────────────────────────────
_JEV_QUESTIONS = {
    "relevant": {
        "type": "noul",
        "instructions": (
            "Is this content materially relevant to a D365FO technical consultant "
            "who works on X++ extensions, SSRS, integrations, and a personal "
            "Linux/Nix automation stack? Unrelated chatter scores low."
        ),
    },
    "material": {
        "type": "noul",
        "instructions": (
            "Does this content contain a material change, risk, deadline, or new "
            "fact that the reader does not already know? A restatement of routine "
            "expected results scores low."
        ),
    },
    "action": {
        "type": "noul",
        "instructions": (
            "Does the reader need to do something about this within the next three "
            "days, or lose something by ignoring it?"
        ),
    },
    "novel": {
        "type": "noul",
        "instructions": (
            "Is this new information rather than a repeat of a routine report the "
            "reader has seen before with the same shape?"
        ),
    },
}


def _jev(state: str) -> tuple[dict | None, str | None]:
    """One jev evaluation. Returns ({relevant, material, action, novel}, error)."""
    key = os.getenv("COMMANDCODE_API_KEY", "")
    if not key:
        return None, "COMMANDCODE_API_KEY not set"
    body = json.dumps({
        "model": "typesafe/jev",
        "state": state,
        "questions": _JEV_QUESTIONS,
    }).encode()
    req = urllib.request.Request(
        COMMANDCODE_S1,
        data=body,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "User-Agent": USER_AGENT,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as resp:
            payload = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        return None, f"jev HTTP {exc.code}"
    except Exception as exc:
        return None, f"jev {type(exc).__name__}"

    answers = payload.get("answers") or {}
    out = {}
    for name in _JEV_QUESTIONS:
        try:
            out[name] = float(answers[name]["noul"])
        except (KeyError, TypeError, ValueError):
            return None, f"jev missing answer '{name}'"
    return out, None


# ── GLM: tie-break + human reason, only for ambiguous verdicts ──────────
_SYSTEM = (
    "You are the relevancy filter of a proactive assistant for a D365FO technical "
    "consultant. Decide whether this scheduled report is worth interrupting him for "
    "right now. Be strict: a routine report whose numbers are unchanged and that "
    "requires no decision is NOT worth an interruption. Reply with ONE JSON object "
    "and nothing else - no prose, no markdown fence."
)


def _glm(report: str, jev_scores: dict) -> tuple[dict | None, str | None]:
    key = os.getenv("COMMANDCODE_API_KEY", "")
    if not key:
        return None, "COMMANDCODE_API_KEY not set"
    user = (
        "Report:\n" + report[:MAX_CHARS] + "\n\n"
        "A fast decision model already scored this report: "
        + json.dumps(jev_scores) + " (0-1, higher = more). "
        "Give the final verdict.\n"
        'Return json: {"relevant":0-1,"material":0-1,"action":true|false,'
        '"reason":"<=12 words"}'
    )
    body = json.dumps({
        "model": FILTER_MODEL,
        "messages": [
            {"role": "system", "content": _SYSTEM},
            {"role": "user", "content": user},
        ],
        "max_tokens": 400,
        "temperature": 0,
    }).encode()
    req = urllib.request.Request(
        COMMANDCODE_CHAT,
        data=body,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "User-Agent": USER_AGENT,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as resp:
            payload = json.loads(resp.read().decode())
        content = (payload["choices"][0]["message"].get("content") or "").strip()
    except urllib.error.HTTPError as exc:
        return None, f"glm HTTP {exc.code}"
    except Exception as exc:
        return None, f"glm {type(exc).__name__}"

    # Models sometimes wrap JSON in a fence despite instructions.
    if content.startswith("```"):
        content = re.sub(r"^```[a-z]*\s*|\s*```$", "", content, flags=re.I).strip()
    match = re.search(r"\{.*\}", content, re.S)
    if not match:
        return None, "glm returned no JSON"
    try:
        parsed = json.loads(match.group(0))
    except json.JSONDecodeError:
        return None, "glm JSON unparseable"
    return parsed, None


# ── verdict ─────────────────────────────────────────────────────────────
def _decide(report: str) -> dict:
    """Return {'action': 'pass'|'drop', 'stage': str, 'reason': str, ...}."""
    pre = _prescreen(report)
    if pre:
        action, reason = pre
        return {"action": action, "stage": "prescreen", "reason": reason, "scores": {}}

    if not ACTION_HINT_RE.search(report):
        # No deadline/risk/change vocabulary anywhere. Cheap prior toward
        # silence, but still let jev confirm rather than deciding alone.
        prior = "no action vocabulary"
    else:
        prior = ""

    scores, err = _jev(report)
    if scores is None:
        # Fail OPEN: a filter outage must not silently swallow a report.
        return {
            "action": "pass",
            "stage": "jev-error",
            "reason": f"{err} -> fail open",
            "scores": {},
        }

    if scores["action"] >= ACTION_OVERRIDE:
        return {
            "action": "pass", "stage": "jev",
            "reason": f"action={scores['action']:.2f} >= {ACTION_OVERRIDE}",
            "scores": scores,
        }
    if scores["material"] < DROP_MATERIAL and scores["action"] < DROP_MATERIAL:
        return {
            "action": "drop", "stage": "jev",
            "reason": f"material={scores['material']:.2f} action={scores['action']:.2f} < {DROP_MATERIAL}"
                      + (f" ({prior})" if prior else ""),
            "scores": scores,
        }
    if scores["material"] >= DELIVER_MATERIAL and scores["relevant"] >= DELIVER_RELEVANT:
        return {
            "action": "pass", "stage": "jev",
            "reason": f"material={scores['material']:.2f} relevant={scores['relevant']:.2f}",
            "scores": scores,
        }

    # Ambiguous band -> escalate once.
    if not ESCALATE:
        return {
            "action": "pass", "stage": "jev-ambiguous",
            "reason": f"ambiguous, escalation disabled ({scores})",
            "scores": scores,
        }
    verdict, gerr = _glm(report, scores)
    if verdict is None:
        return {
            "action": "pass", "stage": "glm-error",
            "reason": f"{gerr} -> fail open",
            "scores": scores,
        }
    try:
        material = float(verdict.get("material", 0))
        relevant = float(verdict.get("relevant", 0))
        action = bool(verdict.get("action"))
    except (TypeError, ValueError):
        return {"action": "pass", "stage": "glm-unmappable",
                "reason": "glm verdict unmappable -> fail open", "scores": scores}

    # GLM is the last authority in the chain: both models have now looked at it.
    # An explicit action flag always delivers; otherwise a report must clear the
    # material bar to justify an interruption. Anything that clears neither is
    # the definition of the noise this gate exists to remove, so it drops here
    # rather than defaulting to delivery.
    if action:
        act = "pass"
    elif material >= DELIVER_MATERIAL and relevant >= DELIVER_RELEVANT:
        act = "pass"
    else:
        act = "drop"
    return {
        "action": act, "stage": "glm",
        "reason": str(verdict.get("reason") or "")[:120],
        "scores": {"jev": scores, "glm": {"material": material, "relevant": relevant, "action": action}},
    }


# ── hook ────────────────────────────────────────────────────────────────
def _on_transform_llm_output(*, response_text: str = "", platform: str = "", **_) -> str | None:
    """transform_llm_output: gate cron deliveries through the relevancy filter."""
    if MODE == "off":
        return None
    if str(platform or "").lower() != "cron":
        return None
    if not isinstance(response_text, str) or not response_text.strip():
        return None

    t0 = time.monotonic()
    try:
        decision = _decide(response_text)
    except Exception as exc:  # never break a turn
        logger.warning("proactive-gate: decision failed: %s", exc)
        return None
    elapsed_ms = int((time.monotonic() - t0) * 1000)

    _log({
        "mode": MODE,
        "action": decision["action"],
        "stage": decision["stage"],
        "reason": decision["reason"],
        "elapsed_ms": elapsed_ms,
        "chars": len(response_text),
        "scores": decision["scores"],
        "head": response_text.strip().splitlines()[0][:100] if response_text.strip() else "",
    })

    if decision["action"] == "drop" and MODE == "enforce":
        logger.info("proactive-gate: suppressed cron delivery (%s: %s)",
                    decision["stage"], decision["reason"])
        return "[SILENT]"

    logger.info("proactive-gate: %s/%s %s (%dms)", decision["action"], decision["stage"],
                decision["reason"], elapsed_ms)
    return None


def register(ctx) -> None:
    ctx.register_hook("transform_llm_output", _on_transform_llm_output)
    logger.info("proactive-gate: active mode=%s drop_material=%.2f deliver_material=%.2f escalate=%s",
                MODE, DROP_MATERIAL, DELIVER_MATERIAL, ESCALATE)
