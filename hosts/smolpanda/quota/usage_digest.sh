#!/usr/bin/env bash
set -uo pipefail
# cron runs with PATH=/usr/bin:/bin: no python3, no dirname, no mkdir.
# Resolve python3 explicitly and use bash builtins for paths so this cannot fail
# on a missing coreutil.
PY=/run/current-system/sw/bin/python3
[ -x "$PY" ] || PY=$(command -v python3 2>/dev/null)
if [ -z "$PY" ]; then echo "no python3" >&2; exit 0; fi
OUTDIR=/var/lib/hermes/.hermes/cache/quota
[ -d "$OUTDIR" ] || mkdir -p "$OUTDIR" 2>/dev/null || true

OUT=$OUTDIR/usage.png
TXT=$("$PY" /var/lib/hermes/.hermes/scripts/usage_report.py 2>/dev/null)
[ -z "$TXT" ] && exit 0
printf '%s' "$TXT" | "$PY" /var/lib/hermes/.hermes/scripts/render_report.py usage "$OUT" >/dev/null 2>&1
if [ -s "$OUT" ]; then
  echo "MEDIA:$OUT"
else
  printf '%s\n' "$TXT"
fi
