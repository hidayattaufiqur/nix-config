#!/usr/bin/env bash
# Cron wrapper for quota_snapshot.py.
#
# Why a wrapper: the cron `script:` field runs the file with no arguments, but
# the snapshot script needs `--check` to stay quiet when every quota is healthy.
# Without this, the 4-hourly job would deliver the full JSON blob every run —
# exactly the noise the proactive-gate exists to prevent, from the job that is
# supposed to be the quiet one.
#
# Why python3 is resolved by absolute path: the cron lane runs with a minimal
# PATH (/usr/bin:/bin) that has no python3 at all, so `env python3` exits 127.
# NixOS also makes a hardcoded /nix/store/... path unsafe — it changes on every
# rebuild that touches Python. /run/current-system/sw/bin/python3 is the stable
# entry point, with `command -v` as a fallback for interactive shells.
#
# Contract: empty stdout = nothing wrong = no delivery (cron suppresses it).
# Non-empty stdout = something crossed a threshold = delivered verbatim.

PY=""
for cand in /run/current-system/sw/bin/python3 /usr/bin/python3; do
  [ -x "$cand" ] && PY="$cand" && break
done
if [ -z "$PY" ]; then
  PY=$(command -v python3 2>/dev/null)
fi
if [ -z "$PY" ]; then
  echo "quota_watch: no python3 found (PATH=$PATH)" >&2
  exit 0   # stay silent: a broken quota check must not spam the channel
fi

exec "$PY" /var/lib/hermes/.hermes/scripts/quota_snapshot.py --check
