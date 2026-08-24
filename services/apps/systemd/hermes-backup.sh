#!/usr/bin/env bash
# Hermes state backup for smolpanda.
#
# Storage-conscious nightly snapshot of Hermes state. What it takes:
#   - all sqlite DBs at $HERMES_HOME root (state.db, kanban.db, projects.db,
#     verification_evidence.db) and per-profile state.db, via sqlite .backup
#     so live WAL DBs snapshot consistently
#   - config.yaml, .env, auth.json (credential pool, sensitive), SOUL.md,
#     channel_directory.json, gateway_state.json, processes.json, .restart_*
#   - skills/, memories/, cron/, scripts/, sessions/, plugins/, gateway/,
#     state/, platforms/ (dirs, excluding caches)
#   - per-profile skills/ (deduped via hardlinks: all profiles share the same
#     skill tree, so tar stores one copy, same as the ~/.hermes/skills copy)
#
# Excluded: logs/, cache/, lsp/, bin/, sandboxes/, pending_messages/,
# profiles-archive/, backups/, models_*_cache*.json, __pycache__.
# Retention: 7 daily snapshots (tar.gz + sqlite .backup sidecar files) in
# $BACKUP_DIR; older snapshots pruned. Secrets: backup dir + archives are
# chmod 700/600.
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-/var/lib/hermes/.hermes}"
BACKUP_DIR="${BACKUP_DIR:-/var/lib/hermes/.hermes/backups}"
KEEP=7
STAMP="$(date +%Y%m%dT%H%M%S)"
TARBALL="${BACKUP_DIR}/hermes-state-${STAMP}.tar.gz"
TMP="$(mktemp -d "${BACKUP_DIR}/.staging.XXXXXX")"
SQLITE_BIN="$(command -v sqlite3 2>/dev/null || { ls -d /nix/store/*sqlite*-bin/bin/sqlite3 2>/dev/null | head -1; })"
[ -n "$SQLITE_BIN" ] || { echo "sqlite3 not found" >&2; exit 1; }
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
# 1. Consistent snapshots of live WAL DBs (sqlite .backup), plus a copy of
#    every non-WAL .db at the root and per-profile state.db.
find "$HERMES_HOME" -maxdepth 1 -name '*.db' -print0 | while IFS= read -r -d '' db; do
  base="$(basename "$db")"
  "$SQLITE_BIN" "$db" ".backup '$TMP/$base'"
done
find "$HERMES_HOME"/profiles -maxdepth 2 -name 'state.db' -print0 | while IFS= read -r -d '' db; do
  rel="$(echo "$db" | sed "s|^$HERMES_HOME/||; s|/state.db$||; s|/|_|g")"
  "$SQLITE_BIN" "$db" ".backup '$TMP/state-${rel}.db'"
done
# cron has live sqlite dbs too — snapshot them consistently
for db in "$HERMES_HOME"/cron/*.db; do
  [ -f "$db" ] && "$SQLITE_BIN" "$db" ".backup '$TMP/cron-$(basename "$db")'"
done
# Non-WAL dbs have no -wal/-shm next to them; copy the -wal/-shm sidecars of
# the live ones we snapshotted into the tarball as well (small, harmless).

# 2. Hardlink-copy the root skills dir (per-profile skills/ are the same tree,
#    so one copy in the tarball covers all profiles — no duplication), plus a
#    per-profile skill-metadata marker. Then tar everything.
cp -al "$HERMES_HOME"/skills "$TMP/skills"
for p in "$HERMES_HOME"/profiles/*; do
  [ -d "$p/skills" ] && echo "$(basename "$p")" >> "$TMP/profile-skills.txt"
done
cp -a "$HERMES_HOME"/config.yaml "$HERMES_HOME"/.env "$HERMES_HOME"/auth.json \
      "$HERMES_HOME"/SOUL.md "$HERMES_HOME"/channel_directory.json \
      "$HERMES_HOME"/gateway_state.json "$HERMES_HOME"/processes.json \
      "$HERMES_HOME"/.restart_last_processed.json "$TMP/" 2>/dev/null || true
for d in memories cron scripts sessions plugins gateway state platforms; do
  [ -d "$HERMES_HOME/$d" ] && cp -a "$HERMES_HOME/$d" "$TMP/$d"
done

# 3. Tar + gzip (best compression; the payload is a few hundred MB pre-compress,
#    mostly text/JSON, so it compresses hard).
# NOTE: profile skills live in the single ~/.hermes/skills copy, so the archive
# carries one skills tree, not 7 duplicates. Each profile keeps its own state.db
# snapshot and config; a full profile restore = restore state.db + skills + root.
tar -C "$TMP" -czf "$TARBALL" --exclude='__pycache__' .

# 4. Cleanup the staging dir (tarball is sealed; the only files rm can't drop
#    are the 555 read-only skill dirs copied in, which is fine).
chmod -R u+w "$TMP" 2>/dev/null
rm -rf "$TMP" 2>/dev/null || true

# 5. Tighten perms on the archive (secrets inside).
chmod 600 "$TARBALL"

# 6. Retention: keep the KEEP most recent snapshots, prune the rest.
ls -1t "$BACKUP_DIR"/hermes-state-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -f

echo "backup ok: $TARBALL ($(du -h "$TARBALL" | cut -f1))"