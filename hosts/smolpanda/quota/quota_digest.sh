#!/usr/bin/env bash
set -uo pipefail
# cron runs with PATH=/usr/bin:/bin: no python3, no dirname, no mkdir.
#
# Output MUST land in one of Hermes' canonical cache subdirs (images/, audio/,
# videos/, documents/, screenshots/). The gateway's media validator denies
# /var/lib outright, so writing to .../cache/quota/ made every MEDIA: line a
# silent no-op -- "Skipping unsafe MEDIA directive path" in the gateway log while
# the job still reported completed.
#
# render_report.py echoes its output path on success; send that to /dev/null so
# the only stdout is the MEDIA: directive. A bare path line in the body is noise
# and makes the message look broken.
PY=/run/current-system/sw/bin/python3
[ -x "$PY" ] || PY=$(command -v python3 2>/dev/null)
if [ -z "$PY" ]; then echo "no python3" >&2; exit 0; fi
OUTDIR=/var/lib/hermes/.hermes/cache/images
[ -d "$OUTDIR" ] || mkdir -p "$OUTDIR" 2>/dev/null || true

OUT=$OUTDIR/quota-digest.png
"$PY" /var/lib/hermes/.hermes/scripts/render_report.py quota "$OUT" >/dev/null 2>&1
if [ -s "$OUT" ]; then
  echo "MEDIA:$OUT"
else
  "$PY" /var/lib/hermes/.hermes/scripts/quota_snapshot.py --digest
fi
