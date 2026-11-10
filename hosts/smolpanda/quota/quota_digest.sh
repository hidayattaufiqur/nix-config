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

OUT=$OUTDIR/digest.png
"$PY" /var/lib/hermes/.hermes/scripts/render_report.py quota "$OUT" 2>/dev/null
if [ -s "$OUT" ]; then
  echo "MEDIA:$OUT"
else
  "$PY" /var/lib/hermes/.hermes/scripts/quota_snapshot.py --digest
fi
