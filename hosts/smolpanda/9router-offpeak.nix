# Time-aware 9router combo routing: keep deepseek-v4-flash (the CommandCode
# models that double in price) out of the peak windows so peak-hour fallbacks
# can't drain the token balance.
#
# CommandCode pricing windows (WIB, UTC+7) per user 2026-08-26:
#   Morning peak   08:00 – 11:00 WIB (01:00 – 04:00 UTC)
#   Afternoon peak 13:00 – 17:00 WIB (06:00 – 10:00 UTC)
#   Everything else is off-peak; 11:00–13:00 is OFF-PEAK.
#
# 9router has no native time-window model weighting (comboStrategies only
# supports fallbackStrategy/judgeModel/fusionTuning), but it resolves combo
# models live from SQLite per request (SELECT * FROM combos WHERE name = ?,
# no cache), so swapping the combo's models JSON is enough — no minified
# bundle patching, no Hermes fallback surgery.
#
# The host's /var/lib/9router bind mount is READONLY from the host shell
# (root fs mounted ro; only the docker container's view of the bind is rw),
# so the swap must run INSIDE the 9router container, where /app/data is
# writable. The container ships better-sqlite3 + node.
#
# Two timers run the same swap at each window edge (a few minutes early so
# the boundary is respected for in-flight requests):
#   * peak-on  at 07:55 / 12:55 WIB  -> drop the two paid deepseek entries
#   * peak-off at 11:05 / 17:05 WIB  -> restore the full model list
#
# The script is idempotent (60s guard) and refuses to touch a combo whose
# current model list matches neither known list — so manual dashboard edits
# are never clobbered, and a manual `systemctl start` works for verification.
{ pkgs, ... }:
let
  combo = "hermes-agent";
  # Off-peak: full list as stored in the DB today.
  offpeakModels = [
    "agentrouter/gpt-5.6-sol"
    "agentrouter/claude-opus-5"
    "agentrouter/deepseek-v4f"
    "oc/muse-spark-1.2-contributor-free"
    "oc/deepseek-v4-flash-free"
    "oc/x-preview-f-free"
    "oc/laguna-s-2.1-free"
    "oc/mimo-v2.5-free"
    "cmc/stealth/ox-alpha"
    "ocg/deepseek-v4-flash"
    "ocg/muse-spark-1.2-contributor"
    "cmc/meta/muse-spark-1.2-contributor"
    "cmc/deepseek/deepseek-v4-flash"
  ];
  # Peak: drop the two paid deepseek entries, keep everything else.
  peakModels = builtins.filter (m: m != "ocg/deepseek-v4-flash" && m != "cmc/deepseek/deepseek-v4-flash") offpeakModels;
  # Node script executed inside the container (writable /app/data bind).
  swapNode = pkgs.writeText "9router-offpeak-swap.mjs" ''
    import { createRequire } from "module";
    const require = createRequire("/app/package.json"); // resolve better-sqlite3 from /app/node_modules
    const Database = require("better-sqlite3");
    const db = new Database("/app/data/db/data.sqlite");
    const OFF = ${builtins.toJSON offpeakModels};
    const PEAK = ${builtins.toJSON peakModels};
    const row = db.prepare("SELECT models FROM combos WHERE name = ?").get("${combo}");
    if (!row) { console.error("combo not found"); process.exit(1); }
    const cur = JSON.parse(row.models);
    const same = (a, b) => a.length === b.length && a.every((x, i) => x === b[i]);
    let mode;
    if (same(cur, OFF)) mode = "OFFPEAK";
    else if (same(cur, PEAK)) mode = "PEAK";
    else { console.log("combo manually edited, skipping"); process.exit(0); }
    const next = mode === "OFFPEAK" ? PEAK : OFF;
    db.prepare("UPDATE combos SET models = ?, updatedAt = ? WHERE name = ?")
      .run(JSON.stringify(next), new Date().toISOString(), "${combo}");
    console.log(`swapped ''${mode} -> ''${next.length} models`);
  '';
  swapScript = pkgs.writeShellScript "9router-offpeak-swap" ''
    set -euo pipefail
    STATE=/tmp/9router-combo-state
    NOW=$(date +%s)
    LAST=$([ -f "$STATE" ] && cat "$STATE" || echo 0)
    [ $((NOW - LAST)) -lt 60 ] && exit 0   # idempotent: both timers fire on boot catch-up
    echo "$NOW" > "$STATE"
    exec ${pkgs.docker}/bin/docker exec 9router node ${swapNode}
  '';
in
{
  systemd.services = {
    "9router-offpeak-peak-on" = {
      description = "9router: drop paid deepseek from combo during CommandCode peak windows";
      serviceConfig = {
        Type = "oneshot";
        User = "smolpanda";
        Group = "users";
        ExecStart = swapScript;
      };
    };
    "9router-offpeak-peak-off" = {
      description = "9router: restore full combo list in off-peak windows";
      serviceConfig = {
        Type = "oneshot";
        User = "smolpanda";
        Group = "users";
        ExecStart = swapScript;
      };
    };
  };

  systemd.timers = {
    "9router-offpeak-peak-on" = {
      description = "9router off-peak: enter peak window (07:55 / 12:55 WIB)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = [ "*-*-* 07:55:00" "*-*-* 12:55:00" ]; # 07:55 / 12:55 WIB (host TZ = WIB)
        Persistent = true;
        Unit = "9router-offpeak-peak-on.service";
      };
    };
    "9router-offpeak-peak-off" = {
      description = "9router off-peak: leave peak window (11:05 / 17:05 WIB)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = [ "*-*-* 11:05:00" "*-*-* 17:05:00" ]; # 11:05 / 17:05 WIB (host TZ = WIB)
        Persistent = true;
        Unit = "9router-offpeak-peak-off.service";
      };
    };
  };
}
