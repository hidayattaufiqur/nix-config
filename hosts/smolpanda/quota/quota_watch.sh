#!/usr/bin/env bash
# Cron wrapper for quota_snapshot.py.
#
# Why a wrapper: the cron `script:` field runs the file with no arguments, but
# the snapshot script needs `--check` to stay quiet when every quota is healthy.
# Without this, the 4-hourly job would deliver the full JSON blob every run —
# exactly the noise the proactive-gate exists to prevent, from the job that is
# supposed to be the quiet one.
#
# Contract: empty stdout = nothing wrong = no delivery (cron suppresses it).
# Non-empty stdout = something crossed a threshold = delivered verbatim.
exec /usr/bin/env python3 /var/lib/hermes/.hermes/scripts/quota_snapshot.py --check
