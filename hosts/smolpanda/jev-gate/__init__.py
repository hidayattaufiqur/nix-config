"""jev-gate plugin — Jev decides whether a command is safe before it runs.

Replaces the human-approval gate for dangerous shell commands
(approvals.mode: off per user decision 2026-10-22, because approval cards on
Discord arrive without a ping and fail closed at the timeout, stalling turns).

Design:
  * pre_tool_call hook on the terminal tool, evaluated on EVERY command.
  * Fast path first: trusted-prefix skip (git status, ls, cat reads with no
    side-effect verbs) and remembers verdicts so repeat shapes cost nothing.
  * Otherwise one jev_evaluate call (Orvix /v1/evaluate, model orvix/jev) with
    a single boolean question: unsafe={0..1}. Jev returns calibrated
    probability in ~100-500ms and costs ~300-1k input tokens.
  * unsafe >= 0.75 -> block; 0.35-0.75 -> block too but say "jev uncertain"
    so the turn can route differently; < 0.35 -> allow.
  * jev failure (network, 4xx) FAILS OPEN - the deterministic seam is the
    deny floor (approvals.deny + hardline blocklist), which still fires.
  * The verdict is also returned to the model as a one-line explanation so
    it can self-correct instead of retrying blind.

The beta rule (t_bebfb70f) applies: act on jev above 0.75 confidence or when
the top option clearly leads; boundary cases are fails, not answers. Here the
bar is asymmetric on purpose - the cost model differs (a blocked safe command
wastes one turn; a run unsafe command can burn a session), so 0.35 is the
block floor, and failure-to-classify fails OPEN to the deny floor, not the
turn.
"""

from __future__ import annotations

import json
import logging
import os
import re
import urllib.request

logger = logging.getLogger(__name__)

# ── tunables (override via env) ─────────────────────────────────────────
# Three bands, because jev has no context about "this is the user's own box":
#   * jev >= BLOCK_CONFIDENT (0.80)  -> block, jev is confident it is unsafe
#   * jev >= BLOCK_UNCERTAIN (0.35)  -> block ONLY if the command also has a
#                                       risky shape (destructive verb, service
#                                       lifecycle, credential access, pipe to
#                                       shell). jev alone is not enough.
#   * jev <  BLOCK_UNCERTAIN         -> allow
# jev has no idea that "systemctl restart nginx" is routine on this box but
# "cat /etc/shadow" is not, so the shape check carries the middle band.
BLOCK_CONFIDENT = float(os.getenv("JEV_GATE_BLOCK_CONFIDENT", "0.80"))
BLOCK_UNCERTAIN = float(os.getenv("JEV_GATE_BLOCK_UNCERTAIN", "0.35"))
FAIL_OPEN = os.getenv("JEV_GATE_FAIL_OPEN", "1") != "0"
TIMEOUT_S = float(os.getenv("JEV_GATE_TIMEOUT_S", "12"))
CACHE_MAX = int(os.getenv("JEV_GATE_CACHE_MAX", "256"))
ORVIX_BASE = os.getenv("ORVIX_BASE_URL", "https://api.orvix.id/v1")

# Recurring, legitimate operations on the user's own box. jev cannot know
# these are expected, and they are what the agent does every single day, so
# they skip jev entirely. Deliberately narrow: read-only service status, a
# restart/reload (never stop/disable/mask), and the nix rebuild path.
KNOWN_GOOD_RES = [
    re.compile(r"^systemctl (status|is-active|is-failed|list-units|list-timers|cat|show)\b", re.I),
    re.compile(r"^systemctl (restart|reload)\s+[A-Za-z0-9_.@-]+(\.service)?$", re.I),
    re.compile(r"^nixos-rebuild (switch|build|dry-run)\b", re.I),
    re.compile(r"^journalctl\b", re.I),
    re.compile(r"^docker (logs|ps|images|inspect|stats|top)\b", re.I),
    re.compile(r"^git (status|log|diff|show|branch|remote|rev-parse|ls-remote)\b", re.I),
    re.compile(r"^(cat|head|tail|ls|stat|wc|file|readlink|which|command -v|type)\s+", re.I),
]

# A read is only "known-good" if it does not point at a secret. Without this,
# "cat /etc/shadow" skipped the gate entirely (it matches the read pattern).
SENSITIVE_PATH_RE = re.compile(
    r"/etc/(shadow|sudoers|passwd|shadow-)\b"
    r"|\bid_rsa\b|\bid_ed25519\b|\bauthorized_keys\b"
    r"|\.ssh/|\.gnupg/|/\.env\b|\.env$|\.env/"
    r"|/proc/1/environ|/var/lib/hermes/.hermes/\.env"
    r"|credentials|\bpasswords?\b|\bsecrets?\b",
    re.IGNORECASE,
)

# Shapes that make a mid-band jev verdict actionable. A mid-band command
# without one of these is allowed.
RISKY_SHAPE_RE = re.compile(
    r"\brm\b|\bmkfs\b|\bdd\b|chmod|chown|truncate|shred"
    r"|systemctl\s+(stop|disable|mask|kill)"
    r"|docker\s+(stop|kill|rm|rmi|prune|down|compose\s+down)"
    r"|pkill|killall|kill\s+-9"
    r"|/etc/shadow|/etc/sudoers|id_rsa|authorized_keys|\.ssh/|\.env\b"
    r"|\bcurl\b|\bwget\b|\bssh\b|\bscp\b"
    r"|\bnpm\s+(install|i)\b|\bpip\s+install\b|\bapt\b|\bdnf\b"
    r"|\bnixos-rebuild\b.*\bswitch\b"
    r"|sudo"
    r"|[|;&<>]"
    r"|\bgit\b.*\b(push|reset --hard|clean -f|filter-branch)\b",
    re.IGNORECASE,
)

# Exact-match safe prefixes: pure reads with no side-effect verbs anywhere.
_SAFE_EXACT_RE = re.compile(
    r"^(?:hermes (?:approvals test|config (?:get|list)|plugins list|gateway (?:list|status))"
    r"|hermes approvals suggest"
    r"|(?:cat|head|tail|ls|stat|wc|file|readlink|which|command -v|type) "
    r"|git (?:status|log|diff|show|branch|remote|rev-parse|ls-remote|worktree list)"
    r"|-{0,2}(?:which|whoami|id|uname|hostname|date|uptime|free|df) ?-?[a-z]*"
    r")",
    re.IGNORECASE,
)
# Bad-actor substrings that always escalate to jev regardless of prefix.
_FORCE_JEV_RE = re.compile(
    r"rm |rm$|rm;$|mkfs|dd if|chmod|chown|systemctl|kill|pkill|killall"
    r"|docker (?:stop|kill|rm|restart|exec|compose|prune|down)"
    r"|curl|wget|ssh |scp|tar|zip|unzip|apt|dnf|nixos-rebuild|nix build|nix eval"
    r"|pip|npm (?:install|i )|git (?:push|reset|clean|rebase|filter-branch)"
    r"|/etc/shadow|/etc/sudoers|id_rsa|authorized_keys|\.env\b"
    # A single pipe is enough to make a read compound: "cat /etc/shadow | wc"
    # is a read by prefix but a leak by pipe.
    r"|[|;&<>]"
    r"|\brm\b"
    r"|sudo",
    re.IGNORECASE,
)

_session_cache: dict[str, float] = {}


def _parse_env_float(name: str, default: float) -> float:
    raw = os.getenv(name)
    if not raw:
        return default
    try:
        return float(raw)
    except ValueError:
        return default


# ── jev call ────────────────────────────────────────────────────────────
def _jev_unsafe_probability(command: str) -> tuple[float | None, str | None]:
    """Ask jev one boolean: is this command unsafe to run?

    Returns (probability or None, reason or None). None + reason means the
    gate could not get an answer (network / upstream error / timeout).
    """
    token = os.getenv("ORVIX_TOKEN", "")
    if not token:
        return None, "ORVIX_TOKEN is not set"

    prompt = (
        "Is this shell command UNSAFE to run on a shared Linux server? "
        "Consider: data destruction beyond the session's own scratch space "
        "(/tmp), impact to other services or daemons, credential exposure, "
        "downloading or executing remote code, and irreversible changes. "
        "Routine infra is FINE: reading logs, git status, package queries, "
        "docker log inspection, curls to read-only APIs, systemctl restart of "
        "services the user manages. Answer ONLY per the question."
    )
    body = json.dumps({
        "model": "orvix/jev",
        "state": f"{prompt}\n\nCOMMAND:\n{command}",
        # Orvix /v1/evaluate expects questions as a MAP keyed by question id,
        # not an array - a sequence sends back HTTP 400 "invalid type:
        # sequence, expected a map" (mirrors jev-mcp evalRequest).
        "questions": {
            "unsafe": {
                "type": "boolean",
                "instructions": "Is the COMMAND unsafe to run?",
            },
        },
    }).encode()

    req = urllib.request.Request(
        f"{ORVIX_BASE}/evaluate",
        data=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            # Cloudflare in front of Orvix 403s (error 1010) the default
            # python urllib User-Agent; a plain curl-style UA passes.
            "User-Agent": "curl/8.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as resp:
            payload = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return None, f"jev HTTP {e.code}: {e.read().decode()[:150]}"
    except Exception as e:  # network, timeout, HTTP error, decode
        return None, f"jev upstream error: {type(e).__name__}"

    try:
        return float(payload["answers"]["unsafe"]["noul"]), None
    except (KeyError, TypeError, ValueError):
        return None, f"jev response unmappable: {str(payload)[:120]}"


def _verdict(command: str) -> tuple[str, str]:
    """Return (action, message) where action is 'skip'|'allow'|'block'."""
    # 1) Known-good shapes: recurring, legitimate work on this box. jev has no
    #    context that they are expected, and they are what the agent does all
    #    day, so they skip the LLM entirely - UNLESS the command touches a
    #    secret path, in which case jev decides.
    if not SENSITIVE_PATH_RE.search(command):
        for rx in KNOWN_GOOD_RES:
            if rx.match(command.strip()):
                return "skip", "known-good shape"

    # 2) Plain read with no side-effect verb: cheap skip.
    if (
        not SENSITIVE_PATH_RE.search(command)
        and _SAFE_EXACT_RE.search(command)
        and not _FORCE_JEV_RE.search(command)
    ):
        return "skip", "trusted read-only shape"

    # 3) jev decides.
    cached = _session_cache.get(command)
    if cached is not None:
        p, reason = cached, "cached"
    else:
        p, reason = g_prob = _jev_unsafe_probability(command)
        if p is None:
            if FAIL_OPEN:
                logger.info("jev-gate: fail-open (%s)", reason)
                return "allow", f"jev unavailable ({reason}) - deny floor still active"
            return "block", f"jev unavailable ({reason})"
        if len(_session_cache) >= CACHE_MAX:
            _session_cache.clear()
        _session_cache[command] = p

    if p >= BLOCK_CONFIDENT:
        return "block", f"jev unsafe={p:.2f} (>= {BLOCK_CONFIDENT}): {command[:120]}"
    if p >= BLOCK_UNCERTAIN and RISKY_SHAPE_RE.search(command):
        return "block", f"jev uncertain={p:.2f} + risky shape: {command[:120]}"
    return "allow", f"jev safe={p:.2f}"


def _prescreen(command: str) -> str | None:
    """Deterministic layer BEFORE jev: hardline-style veto shapes.

    These are shapes jev should never get to allow, because they are
    irreversible or reach outside the box the user cares about.
    """
    low = command.lower()
    # Rootfs wipe / block device / provider abuse - mirrors the built-in
    # UNRECOVERABLE blocklist the hardline floor uses.
    if re.search(r"rm\s+(?:-[a-z]+\s+)*--no-preserve-root\s+/|rm\s+(?:-[a-z]*[rf][a-z]*\s+)+/\s*$", low):
        return "rm of filesystem root"
    if re.search(r"mkfs\.|dd\s+if=.+/zero|:\(\)\{.*\};:", low):
        return "irreversible filesystem/fork-bomb shape"
    # .env and SSH secrets - credential exfil risk.
    if re.search(r"(?:>|>>|tee)\s*.{0,80}(?:\.env|\.ssh|/etc/shadow)", low):
        return "secret file write"
    return None


def _on_pre_tool_call(*, tool_name: str = "", args=None, **_) -> dict | None:
    """pre_tool_call hook: gate terminal commands through jev."""
    if tool_name != "terminal":
        return None
    command = (args or {}).get("command") if isinstance(args, dict) else None
    if not isinstance(command, str) or not command.strip():
        return None

    prescreen = _prescreen(command)
    if prescreen:
        return {"action": "block", "message": f"jev-gate/block: {prescreen} (deterministic prescreen)"}

    action, message = _verdict(command)
    if action == "skip":
        return None
    if action == "allow":
        logger.info("jev-gate: allow %s", message)
        return None
    return {"action": "block", "message": f"jev-gate/block: {message}"}


def register(ctx) -> None:
    ctx.register_hook("pre_tool_call", _on_pre_tool_call)
    logger.info("jev-gate: active (block>=%.2f or uncertain>=%.2f; fail_open=%s)",
                BLOCK_THRESHOLD, WARN_THRESHOLD, FAIL_OPEN)
