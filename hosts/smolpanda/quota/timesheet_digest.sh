#!/usr/bin/env bash
set -uo pipefail
# Timesheet progress card for the daily 9 Dots prep job.
#
# The cron job itself is LLM-driven and writes the .md/.txt table; this renders the
# same week's numbers as an image so the progress bar is readable at a glance.
# Numbers come straight from ODS, not from the job's prose, so the card cannot
# disagree with the source.
#
# cron PATH=/usr/bin:/bin has no python3 and no docker: both are resolved absolutely.
PY=/run/current-system/sw/bin/python3
[ -x "$PY" ] || PY=$(command -v python3 2>/dev/null)
[ -z "$PY" ] && { echo "no python3" >&2; exit 0; }
OUTDIR=/var/lib/hermes/.hermes/cache/images
[ -d "$OUTDIR" ] || mkdir -p "$OUTDIR" 2>/dev/null || true
JSON=$OUTDIR/.timesheet-latest.json
OUT=$OUTDIR/timesheet.png

"$PY" /var/lib/hermes/.hermes/scripts/timesheet_card.py --json "$JSON" 2>/dev/null || exit 0
"$PY" /var/lib/hermes/.hermes/scripts/render_report.py timesheet "$OUT" --json "$JSON" >/dev/null 2>&1

[ -s "$OUT" ] && echo "MEDIA:$OUT"
exit 0
