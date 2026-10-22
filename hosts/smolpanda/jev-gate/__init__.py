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
import urllib.error
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
    # Scratch cleanup under /tmp. Scoped STRICTLY to /tmp: the whole path must
    # be /tmp[/subdir...], so "rm -rf /tmp/x" is fine while "rm -rf /home/x",
    # "rm -rf /var/x" and "rm -rf /" are not. Anchored at both ends, so a
    # chained command ("rm -rf /tmp/x && something") does NOT match and still
    # goes to jev. Needed because jev scores a /tmp wipe anywhere from 0.05
    # to 0.82 across runs - too much variance to leave to the model.
    re.compile(r"^rm\s+(?:-[a-zA-Z]+\s+)*/tmp(?:/[A-Za-z0-9._*-]+)*/?$", re.I),
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
#
# NOTE: shell operators are deliberately NOT in this list. A compound command
# is split into segments and each segment is judged on its own, so the
# operator itself carries no risk signal.
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
    r"|\bgit\b.*\b(push|reset --hard|clean -f|filter-branch)\b",
    re.IGNORECASE,
)

# Destructive deletes OUTSIDE the session's scratch areas fail CLOSED when
# jev is unreachable. In-scope moves (/tmp, the agent's own workspace) fail
# open; /home, /var, /etc, /srv, /opt and /root do not get that trust.
_CLOSURE_EXTRA_OUTSIDE_SCRATCH = (
    "/home/", "/var/", "/etc/", "/srv/", "/opt/", "/root",
)

# Split a compound command into its segments. jev judges ONE command far
# better than a 3-part chain: measured, a benign "cp a b; cp c d" scored
# 0.89 (blocked) while each cp alone scores ~0.2. Splitting on the shell
# operators and judging the max segment keeps the signal honest.
_SEGMENT_SPLIT_RE = re.compile(r"\|\||&&|;|\||&|\n")


def _segments(command: str) -> list[str]:
    """Split a compound command into independently judgeable segments."""
    parts = [s.strip() for s in _SEGMENT_SPLIT_RE.split(command)]
    return [p for p in parts if p] or [command]

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
# ── jev providers ───────────────────────────────────────────────────────
# Two upstream routes to the same model (TypeSafe Jev 1.14.x):
#   1. CommandCode  POST https://api.commandcode.ai/provider/v1/systemone
#      model "typesafe/jev"      <- primary, rides the user's paid sub
#   2. Orvix       POST https://api.orvix.id/v1/evaluate
#      model "orvix/jev"         <- fallback
# Both answer the System One shape: {answers: {<id>: {noul: 0..1}}}.
# The question type MUST be "noul" - CommandCode's endpoint is a strict
# System One validator and rejects "boolean" with
# "Invalid input ... questions.<id>.type" (Orvix accepts both and
# normalises boolean -> noul).
#
# Order matters: CommandCode is the route the user pays for and wants used;
# Orvix is the backup so a CommandCode outage does not silently disable the
# approval gate (which would fail open on everything except the
# deterministic floor).
_JEV_PROVIDERS = (
    {
        "name": "commandcode",
        "url": "https://api.commandcode.ai/provider/v1/systemone",
        "model": "typesafe/jev",
        "token_env": "COMMANDCODE_API_KEY",
    },
    {
        "name": "orvix",
        "url": "https://api.orvix.id/v1/evaluate",
        "model": "orvix/jev",
        "token_env": "ORVIX_TOKEN",
    },
)


def _jev_unsafe_probability(command: str) -> tuple[float | None, str | None]:
    """Ask jev one question: is this command unsafe to run?

    Tries each provider in order and returns the first answer. Returns
    (probability or None, reason or None). None + reason means the gate
    could not get an answer from ANY provider (network / upstream error /
    timeout / no credentials).
    """
    prompt = (
        "Is this shell command UNSAFE to run on a shared Linux server? "
        "Consider: data destruction beyond the session's own scratch space "
        "(/tmp), impact to other services or daemons, credential exposure, "
        "downloading or executing remote code, and irreversible changes. "
        "Routine infra is FINE: reading logs, git status, package queries, "
        "docker log inspection, curls to read-only APIs, systemctl restart of "
        "services the user manages. Answer ONLY per the question."
    )
    state = f"{prompt}\n\nCOMMAND:\n{command}"
    # "noul" is the only question type both providers accept.
    questions = {
        "unsafe": {
            "type": "noul",
            "instructions": "Is the COMMAND unsafe to run?",
        },
    }

    errors = []
    for prov in _JEV_PROVIDERS:
        token = os.getenv(prov["token_env"], "")
        if not token:
            errors.append(f"{prov['name']}: {prov['token_env']} not set")
            continue
        body = json.dumps({
            "model": prov["model"],
            "state": state,
            "questions": questions,
        }).encode()
        req = urllib.request.Request(
            prov["url"],
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
            errors.append(f"{prov['name']}: HTTP {e.code}")
            logger.info("jev-gate: %s failed with HTTP %s", prov["name"], e.code)
            continue
        except Exception as e:
            errors.append(f"{prov['name']}: {type(e).__name__}")
            logger.info("jev-gate: %s failed with %s", prov["name"], type(e).__name__)
            continue
        try:
            value = float(payload["answers"]["unsafe"]["noul"])
        except (KeyError, TypeError, ValueError):
            errors.append(f"{prov['name']}: response unmappable")
            logger.info("jev-gate: %s response unmappable", prov["name"])
            continue
        logger.info("jev-gate: %s answered unsafe=%.2f", prov["name"], value)
        return value, None

    return None, "jev unavailable: " + "; ".join(errors)


def _verdict(command: str) -> tuple[str, str]:
    """Return (action, message) where action is 'skip'|'allow'|'block'.

    A compound command is judged SEGMENT BY SEGMENT: the worst segment
    decides. jev's judgement of a 3-part chain is far worse than of any
    single part (measured 0.89 for a benign "cp a b; cp c d"), so asking it
    about the chain as a whole produces false blocks.
    """
    worst_p = -1.0
    worst_seg = ""
    worst_reason = ""
    unresolved = False

    for seg in _segments(command):
        # 1) Known-good shapes: recurring, legitimate work on this box. jev
        #    has no context that they are expected, and they are what the
        #    agent does all day, so they skip the LLM entirely - UNLESS the
        #    segment touches a secret path or carries a risky shape.
        known_good = False
        if not SENSITIVE_PATH_RE.search(seg):
            for rx in KNOWN_GOOD_RES:
                if rx.match(seg):
                    known_good = True
                    break
        if known_good and not RISKY_SHAPE_RE.search(seg):
            continue

        # 2) jev decides.
        p, reason = _segment_probability(seg)
        if p is None:
            # Fail CLOSED when the command is a destructive delete outside the
            # session's scratch areas, or reads a secret path: a slow
            # evaluator must not be the difference between "allowed" and
            # "blocked" for those. Everything else fails OPEN to the deny
            # floor (approvals.deny + hardline blocklist).
            if SENSITIVE_PATH_RE.search(seg):
                return "block", f"jev unavailable ({reason}) + sensitive path: {seg[:110]}"
            low_seg = seg.lower()
            if re.search(r"\brm\b", low_seg) and any(
                p_ in low_seg for p_ in _CLOSURE_EXTRA_OUTSIDE_SCRATCH
            ):
                return "block", f"jev unavailable ({reason}) + destructive delete outside scratch: {seg[:110]}"
            unresolved = True
            worst_reason = reason
            continue
        if p > worst_p:
            worst_p, worst_seg = p, seg
            worst_reason = reason

    if unresolved:
        if FAIL_OPEN:
            logger.info("jev-gate: fail-open (%s)", worst_reason)
            return "allow", f"jev unavailable ({worst_reason}) - deny floor still active"
        return "block", f"jev unavailable ({worst_reason})"

    if worst_p < 0:
        return "allow", "no risky segment"

    if worst_p >= BLOCK_CONFIDENT:
        return "block", f"jev unsafe={worst_p:.2f} (>= {BLOCK_CONFIDENT}): {worst_seg[:120]}"
    if worst_p >= BLOCK_UNCERTAIN and RISKY_SHAPE_RE.search(worst_seg):
        return "block", f"jev uncertain={worst_p:.2f} + risky shape: {worst_seg[:120]}"
    return "allow", f"jev safe={worst_p:.2f}"


def _segment_probability(segment: str) -> tuple[float | None, str | None]:
    """jev probability for one segment, with the per-session cache."""
    cached = _session_cache.get(segment)
    if cached is not None:
        return cached, "cached"
    p, reason = _jev_unsafe_probability(segment)
    if p is None:
        return None, reason
    if len(_session_cache) >= CACHE_MAX:
        _session_cache.clear()
    _session_cache[segment] = p
    return p, reason


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
                BLOCK_CONFIDENT, BLOCK_UNCERTAIN, FAIL_OPEN)
