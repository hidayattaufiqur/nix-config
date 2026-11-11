#!/usr/bin/env python3
"""timesheet_card.py — weekly timesheet progress as a PNG card.

Why a separate collector: the cron job that produces the timesheet is LLM-driven,
so scraping its prose for numbers would be brittle and could silently disagree
with the source. This reads the ODS replica directly and computes the figures
itself, so the card and the .md/.txt table are derived from the same query.

Output is a JSON doc consumed by render_report.py --kind timesheet, so the visual
styling stays in one place.

Usage:
    timesheet_card.py [--week YYYY-MM-DD] [--json PATH]
  --week  any date inside the target week (default: today, WIB). Weeks are Mon-Sun.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone

WIB = timezone(timedelta(hours=7))
TARGET_HOURS = 40.0
ODS_CONTAINER = "notion-helix-notion-ods-1"

# cron runs with PATH=/usr/bin:/bin, which has no docker. Resolve it.
DOCKER_CANDIDATES = [
    "/run/current-system/sw/bin/docker",
    "/usr/bin/docker",
    "/usr/local/bin/docker",
]


def _docker() -> str | None:
    for c in DOCKER_CANDIDATES:
        if os.access(c, os.X_OK):
            return c
    from shutil import which
    return which("docker")


def _psql(sql: str) -> list[list[str]]:
    """Run one query and return rows as lists of strings."""
    dk = _docker()
    if not dk:
        raise SystemExit("timesheet_card: no docker found")
    p = subprocess.run(
        [dk, "exec", ODS_CONTAINER, "psql", "-U", "notion", "-d", "notion",
         "-t", "-A", "-F", "\x1f", "-c", sql],
        capture_output=True, text=True, timeout=120)
    if p.returncode != 0:
        raise SystemExit(f"timesheet_card: psql failed: {p.stderr[:300]}")
    out = []
    for line in (p.stdout or "").splitlines():
        if line.strip():
            out.append(line.split("\x1f"))
    return out


def week_bounds(anchor: date) -> tuple[date, date]:
    mon = anchor - timedelta(days=anchor.weekday())
    return mon, mon + timedelta(days=6)


def collect(anchor: date) -> dict:
    mon, sun = week_bounds(anchor)
    ms, ss = mon.isoformat(), sun.isoformat()
    # Day expression must match the skill's rule: hours land on timeline_date,
    # falling back to the start-time day when timeline_date is null.
    day = ("coalesce(t.timeline_date,"
           "(t.started_at AT TIME ZONE 'Asia/Jakarta')::date)")

    daily = {}
    for row in _psql(f"""
        SELECT to_char({day},'YYYY-MM-DD') d,
               count(*) n,
               round(sum(t.minutes)/60.0,2) h
          FROM ods.task t
         WHERE t.category_key='cat:nine_dots'
           AND t.minutes > 0
           AND {day} BETWEEN '{ms}' AND '{ss}'
         GROUP BY 1 ORDER BY 1;"""):
        daily[row[0]] = {"rows": int(row[1]), "hours": float(row[2])}

    # Overlaps: wall-clock elapsed double-counts simultaneous logs.
    overlap_rows = _psql(f"""
        WITH t AS (
          SELECT t.name, t.started_at, t.ended_at FROM ods.task t
           WHERE t.category_key='cat:nine_dots' AND t.minutes > 0
             AND t.started_at >= '{ms} 00:00+07'
             AND t.started_at <  ('{ss}'::date + 1)::timestamp + interval '0'
        )
        SELECT to_char(greatest(a.started_at,b.started_at) AT TIME ZONE 'Asia/Jakarta','YYYY-MM-DD'),
               round(sum(extract(epoch from (least(a.ended_at,b.ended_at)
                        - greatest(a.started_at,b.started_at)))/3600.0),2)
          FROM t a JOIN t b ON a.name < b.name
           AND a.started_at < b.ended_at AND b.started_at < a.ended_at
         GROUP BY 1 ORDER BY 1;""")
    overlaps = {r[0]: float(r[1]) for r in overlap_rows}

    # Timeline vs start-date disagreements: flag only when the day differs.
    mismatch = _psql(f"""
        SELECT count(*) FROM ods.task t
         WHERE t.category_key='cat:nine_dots' AND t.minutes > 0
           AND t.timeline_date IS NOT NULL AND t.started_at IS NOT NULL
           AND t.timeline_date <> (t.started_at AT TIME ZONE 'Asia/Jakarta')::date
           AND t.timeline_date BETWEEN '{ms}' AND '{ss}';""")
    mismatches = int(mismatch[0][0]) if mismatch else 0

    # Zero-minute rows in the week: real tasks that carry no time yet.
    pending = _psql(f"""
        SELECT count(*) FROM ods.task t
         WHERE t.category_key='cat:nine_dots'
           AND coalesce(t.minutes,0) = 0
           AND coalesce(t.timeline_date,
                        (t.started_at AT TIME ZONE 'Asia/Jakarta')::date)
               BETWEEN '{ms}' AND '{ss}';""")
    pending_rows = [{"name": r[0]} for r in _psql(f"""
        SELECT t.name FROM ods.task t
         WHERE t.category_key='cat:nine_dots'
           AND coalesce(t.minutes,0) = 0
           AND coalesce(t.timeline_date,
                        (t.started_at AT TIME ZONE 'Asia/Jakarta')::date)
               BETWEEN '{ms}' AND '{ss}'
         ORDER BY t.name LIMIT 8;""")]

    # ODS freshness, so a stale replica cannot be mistaken for "no work".
    fresh = _psql("SELECT to_char(max(synced_at) AT TIME ZONE 'Asia/Jakarta',"
                  "'YYYY-MM-DD HH24:MI') FROM ods.ods_meta;")

    days = []
    for i in range(7):
        d = (mon + timedelta(days=i)).isoformat()
        rec = daily.get(d, {"rows": 0, "hours": 0.0})
        days.append({
            "date": d,
            "dow": (mon + timedelta(days=i)).strftime("%a"),
            "hours": rec["hours"],
            "rows": rec["rows"],
            "is_future": (mon + timedelta(days=i)) > datetime.now(WIB).date(),
            "overlap": overlaps.get(d, 0.0),
        })

    wtd = round(sum(d["hours"] for d in days), 2)
    return {
        "generated_at": datetime.now(WIB).isoformat(timespec="seconds"),
        "week_start": ms,
        "week_end": ss,
        "week_no": mon.isocalendar()[1],
        "target": TARGET_HOURS,
        "week_to_date": wtd,
        "remaining": round(TARGET_HOURS - wtd, 2),
        "percent": round(100.0 * wtd / TARGET_HOURS, 1),
        "days": days,
        "overlaps": overlaps,
        "overlap_total": round(sum(overlaps.values()), 2),
        "mismatches": mismatches,
        "pending_count": int(pending[0][0]) if pending else 0,
        "pending_names": [p["name"] for p in pending_rows],
        "ods_freshness": fresh[0][0] if fresh else "?",
    }


def main() -> int:
    anchor = datetime.now(WIB).date()
    if "--week" in sys.argv:
        anchor = date.fromisoformat(sys.argv[sys.argv.index("--week") + 1])
    doc = collect(anchor)
    if "--json" in sys.argv:
        out = sys.argv[sys.argv.index("--json") + 1]
        with open(out, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(doc, indent=1))
    else:
        print(json.dumps(doc, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
