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
# Two timers run the same swap script at each window edge (a few minutes
# early so the boundary is respected for in-flight requests):
#   * peak-on  at 07:55 / 12:55 WIB  -> drop the two paid deepseek entries
#   * peak-off at 11:05 / 17:05 WIB  -> restore the full model list
#
# The script is idempotent (60s guard) and refuses to touch a combo whose
# current model list matches neither known list — so manual dashboard edits
# are never clobbered, and a manual `systemctl start` works for verification.
{ pkgs, ... }:
let
  db = "/var/lib/9router/data/db/data.sqlite";
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
  sqlite = "${pkgs.sqlite}/bin/sqlite3";
  swapScript = pkgs.writeShellScript "9router-offpeak-swap" ''
    set -euo pipefail
    STATE=/tmp/9router-combo-state
    NOW=$(date +%s)
    LAST=$([ -f "$STATE" ] && cat "$STATE" || echo 0)
    [ $((NOW - LAST)) -lt 60 ] && exit 0   # idempotent: both timers fire on boot catch-up
    echo "$NOW" > "$STATE"

    MODE=$(${sqlite} "$DB" "SELECT CASE
      WHEN (SELECT count(*) FROM json_each((SELECT models FROM combos WHERE name = '$COMBO'))) = $OFF_COUNT
           AND EXISTS(SELECT 1 FROM json_each((SELECT models FROM combos WHERE name = '$COMBO')) WHERE value IN ('ocg/deepseek-v4-flash','cmc/deepseek/deepseek-v4-flash'))
        THEN 'OFFPEAK'
      WHEN (SELECT count(*) FROM json_each((SELECT models FROM combos WHERE name = '$COMBO'))) = $PEAK_COUNT
           AND NOT EXISTS(SELECT 1 FROM json_each((SELECT models FROM combos WHERE name = '$COMBO')) WHERE value IN ('ocg/deepseek-v4-flash','cmc/deepseek/deepseek-v4-flash'))
        THEN 'PEAK'
      ELSE 'UNKNOWN' END")
    case "$MODE" in
      OFFPEAK) ${sqlite} "$DB" "UPDATE combos SET models = '$PEAK_JSON', updatedAt = strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE name = '$COMBO'" ;;
      PEAK)    ${sqlite} "$DB" "UPDATE combos SET models = '$OFF_JSON', updatedAt = strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE name = '$COMBO'" ;;
      UNKNOWN) echo "9router-offpeak: $COMBO manually edited, skipping" ;;
    esac
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
        Environment = [
          "DB=${db}"
          "COMBO=${combo}"
          "OFF_JSON=${builtins.toJSON offpeakModels}"
          "PEAK_JSON=${builtins.toJSON peakModels}"
          "OFF_COUNT=${builtins.toString (builtins.length offpeakModels)}"
          "PEAK_COUNT=${builtins.toString (builtins.length peakModels)}"
        ];
        ExecStart = swapScript;
      };
    };
    "9router-offpeak-peak-off" = {
      description = "9router: restore full combo list in off-peak windows";
      serviceConfig = {
        Type = "oneshot";
        User = "smolpanda";
        Group = "users";
        Environment = [
          "DB=${db}"
          "COMBO=${combo}"
          "OFF_JSON=${builtins.toJSON offpeakModels}"
          "PEAK_JSON=${builtins.toJSON peakModels}"
          "OFF_COUNT=${builtins.toString (builtins.length offpeakModels)}"
          "PEAK_COUNT=${builtins.toString (builtins.length peakModels)}"
        ];
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
