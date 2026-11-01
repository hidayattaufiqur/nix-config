#!/usr/bin/env python3
"""Nightly integrity check for Hermes state.db files.

WHY THIS EXISTS
---------------
On 2026-11-01 the gateway answered a message with "session storage could not
be written" and stopped the turn. The cause was NOT a full disk (64G free) but
SQLite corruption in state.db: the `sessions` b-tree was malformed, so INSERT
failed while PK lookups still worked.

The trap: after the gateway restarted, `PRAGMA quick_check` returned `ok`
(WAL replay had rewritten the bad page) even though 108 session rows had
already been silently dropped, leaving 12,403 orphaned messages. A green
quick_check is therefore NOT proof of health.

So this script checks four things a quick_check alone misses:
  1. quick_check + integrity_check        -> structural corruption
  2. foreign_key_check                    -> orphaned child rows, by table
  3. orphaned messages / usage rows       -> the signature of lost parent rows
  4. drift vs a stored baseline           -> rows disappearing over time

Exit codes: 0 = healthy, 1 = warnings (drift), 2 = corruption/orphans found.
Prints nothing when healthy unless --verbose, so it can be cron'd as a
watchdog (silent when fine, speaks when not).

Usage:
    db_integrity_check.py            # check all profile DBs, quiet when healthy
    db_integrity_check.py --verbose  # always print the full report
    db_integrity_check.py --json     # machine-readable
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import sqlite3
import sys
import time

HERMES_HOME = os.environ.get("HERMES_HOME", "/var/lib/hermes/.hermes")
BASELINE = os.path.join(HERMES_HOME, "state.db.integrity-baseline.json")

# Orphan counts above these thresholds are treated as real damage rather than
# historical residue. They are per-database.
ORPHAN_WARN = 50
# A session count dropping by more than this fraction vs baseline is drift.
DRIFT_WARN_PCT = 0.02


def discover() -> list[str]:
    dbs = [os.path.join(HERMES_HOME, "state.db")]
    dbs += sorted(glob.glob(os.path.join(HERMES_HOME, "profiles", "*", "state.db")))
    return [d for d in dbs if os.path.exists(d)]


def check(db: str) -> dict:
    out = {
        "db": db,
        "size_mb": round(os.path.getsize(db) / 1e6, 1),
        "quick_check": None,
        "integrity_check": None,
        "fk_violations": {},
        "fk_total": 0,
        "orphan_messages": 0,
        "orphan_usage": 0,
        "counts": {},
        "errors": [],
    }
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=30)
        cur = con.cursor()

        try:
            out["quick_check"] = cur.execute("PRAGMA quick_check").fetchone()[0]
        except Exception as e:
            out["quick_check"] = f"ERROR {type(e).__name__}: {str(e)[:60]}"

        try:
            rows = cur.execute("PRAGMA integrity_check").fetchall()
            out["integrity_check"] = "ok" if len(rows) == 1 and rows[0][0] == "ok" else rows[0][0][:120]
        except Exception as e:
            out["integrity_check"] = f"ERROR {str(e)[:60]}"

        # Row counts (also feeds drift detection).
        for t in ("sessions", "messages", "session_model_usage", "system_prompts"):
            try:
                out["counts"][t] = cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
            except Exception as e:
                out["counts"][t] = None
                out["errors"].append(f"{t}: {str(e)[:50]}")

        # FK violations grouped by table (names the orphan source).
        try:
            for r in cur.execute("PRAGMA foreign_key_check").fetchall():
                out["fk_violations"][r[0]] = out["fk_violations"].get(r[0], 0) + 1
            out["fk_total"] = sum(out["fk_violations"].values())
        except Exception as e:
            out["errors"].append(f"fk_check: {str(e)[:50]}")

        # The specific signature of lost parent rows.
        try:
            out["orphan_messages"] = cur.execute("""
                SELECT COUNT(DISTINCT m.session_id) FROM messages m
                LEFT JOIN sessions s ON s.id = m.session_id WHERE s.id IS NULL
            """).fetchone()[0]
        except Exception as e:
            out["errors"].append(f"orphan_messages: {str(e)[:50]}")

        try:
            out["orphan_usage"] = cur.execute("""
                SELECT COUNT(*) FROM session_model_usage u
                LEFT JOIN sessions s ON s.id = u.session_id WHERE s.id IS NULL
            """).fetchone()[0]
        except Exception as e:
            out["errors"].append(f"orphan_usage: {str(e)[:50]}")

        con.close()
    except Exception as e:
        out["errors"].append(f"open: {type(e).__name__}: {str(e)[:60]}")
    return out


def load_baseline() -> dict:
    try:
        with open(BASELINE) as f:
            return json.load(f)
    except Exception:
        return {}


def save_baseline(results: list[dict]) -> None:
    data = {r["db"]: {"counts": r["counts"], "saved_at": time.time()} for r in results}
    tmp = BASELINE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=1)
    os.replace(tmp, BASELINE)


def assess(r: dict, baseline: dict) -> tuple[int, list[str]]:
    """Return (severity, notes). 0 clean, 1 warning, 2 damage."""
    notes: list[str] = []
    sev = 0

    if r["errors"]:
        sev = max(sev, 2)
        notes += [f"error: {e}" for e in r["errors"]]

    for key in ("quick_check", "integrity_check"):
        v = r[key]
        if v not in ("ok", None):
            sev = max(sev, 2)
            notes.append(f"{key}: {v}")

    if r["orphan_messages"] > ORPHAN_WARN:
        sev = max(sev, 2)
        notes.append(f"{r['orphan_messages']} orphaned session_ids in messages")
    elif r["orphan_messages"]:
        sev = max(sev, 1)
        notes.append(f"{r['orphan_messages']} orphaned session_ids (below warn threshold)")

    if r["orphan_usage"]:
        sev = max(sev, 1)
        notes.append(f"{r['orphan_usage']} orphaned session_model_usage rows")

    base = baseline.get(r["db"], {}).get("counts", {})
    for t, cur_n in r["counts"].items():
        prev = base.get(t)
        if isinstance(prev, int) and isinstance(cur_n, int) and prev:
            if t == "sessions" and cur_n < prev * (1 - DRIFT_WARN_PCT):
                sev = max(sev, 1)
                notes.append(f"{t} dropped {prev} -> {cur_n} ({cur_n - prev:+d})")
    return sev, notes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--no-baseline", action="store_true",
                    help="check only, do not read or write the baseline")
    args = ap.parse_args()

    dbs = discover()
    if not dbs:
        print("no state.db files found under", HERMES_HOME, file=sys.stderr)
        return 2

    baseline = {} if args.no_baseline else load_baseline()
    results, worst, all_notes = [], 0, []
    for db in dbs:
        r = check(db)
        sev, notes = assess(r, baseline)
        r["severity"], r["notes"] = sev, notes
        results.append(r)
        worst = max(worst, sev)
        if notes:
            all_notes.append((db, notes))

    if args.json:
        print(json.dumps({"worst": worst, "results": results}, indent=1))
    else:
        healthy = worst == 0
        if args.verbose or not healthy:
            for r in results:
                name = r["db"].replace(HERMES_HOME, "~/.hermes")
                flag = {0: "OK  ", 1: "WARN", 2: "FAIL"}[r["severity"]]
                print(f"{flag} {name}  {r['size_mb']}MB  "
                      f"sessions={r['counts'].get('sessions')} "
                      f"messages={r['counts'].get('messages')} "
                      f"fk={r['fk_total']} orphans={r['orphan_messages']}")
                for n in r["notes"]:
                    print(f"       - {n}")
            if healthy and args.verbose:
                print("\nall databases healthy")

    if not args.no_baseline:
        save_baseline(results)

    return worst


if __name__ == "__main__":
    sys.exit(main())
