# Time-aware 9router combo routing, v2 (2026-10-22).
#
# Two changes vs v1:
#  1. Free OpenCode legs appended as an OFF-PEAK-ONLY tail. Ranked by the
#     2026-10-22 agentic eval (code-correctness weighted most):
#       deepseek-v4.1-flash-free (71.4, best code) > glm-5.3-flash-free (75.2)
#       > mimo-v2.6-flash-free (66.7). minimax-m3.1-flash-free scored equal to
#       glm but is ALREADY the first cmc leg via CommandCode, so it is not
#       duplicated. Legs are LAST, not head: a rate-limited free leg is retried
#       on EVERY request (no durable cooldown on the noAuth oc lane), so at the
#       head it taxes every request ~1-2s; at the tail it is only reached when
#       all cmc legs fail.
#  2. PEAK now unifies both protections: paid deepseek stripped (price doubling)
#     AND free oc/ legs held back (the whole oc lane shares one IP-scoped quota
#     with retry-after up to ~18h; burning it at peak on fallback noise leaves
#     you with nothing for the evening).
#
# Allowlist is CURATED, not dynamic: models are added by hand after an eval
# (user rule: no poor brain in the combo). The upstream sweep in the swap
# script AUTO-REMOVES legs whose model has vanished from the Zen model list
# (deprecated/retired), because a dead leg is pure cost - but never auto-adds.
#
# CommandCode pricing windows (WIB, UTC+7), earlier doc still applies:
#   Morning peak   08:00 - 11:00 WIB
#   Afternoon peak 13:00 - 17:00 WIB
#
# Same mechanics as v1: 9router resolves combo models live from SQLite per
# request, so swapping the combo JSON is enough. The script is idempotent
# (60s guard) and still refuses to touch a combo it does not recognize
# EXCEPT for one safe class of edit: pruning legs that no longer exist
# upstream. Manual dashboard edits survive; only dead models are removed.
{ pkgs, ... }:
let
  combo = "hermes-agent";

  # CommandCode legs - the primary brain. Order chosen by real cost/quality:
  # minimax-m3.1-flash is ~$0.51/M prompt (near-free), muse-spark ~$0.04/M,
  # deepseek-v4.1-flash ~$0.14/M but the best coder of the cmc set.
  cmcLegs = [
    "cmc/minimax/minimax-m3.1-flash:free"
    "cmc/z-ai/glm-5.3-flash"
    "cmc/xiaomi/mimo-v2.6-flash"
    "cmc/claude-haiku-5-5"
    "cmc/deepseek/deepseek-v4.1-flash"
    "cmc/meta/muse-spark-1.3"
  ];
  # Free OpenCode legs - off-peak tail only. Curated from the 2026-10-22 eval.
  # NOTE: nemotron-3-ultra-free was removed here - the upstream sweep proved it
  # retired (only nemotron-3.5-lightning-free / -super-vl-free remain). New
  # free models are NOT auto-added: they wait for an eval + explicit approval.
  ocFreeLegs = [
    "oc/deepseek-v4.1-flash-free"
    "oc/glm-5.3-flash-free"
    "oc/mimo-v2.6-flash-free"
  ];

  peakModels = cmcLegs;
  offpeakModels = cmcLegs ++ ocFreeLegs;

  # Node script executed inside the 9router container (writable /app/data bind;
  # better-sqlite3 resolves from /app/node_modules). Two phases:
  #   phase 1: sweep the upstream /zen/v1/models list and PRUNE any allowlist
  #            leg whose model id has disappeared (deprecated/retired).
  #   phase 2: swap OFFPEAK <-> PEAK if the current list matches; prune safe,
  #            otherwise leave a manual edit untouched (and report it).
  swapNode = pkgs.writeText "9router-offpeak-swap.mjs" ''
    import crypto from "node:crypto";
    import { createRequire } from "module";

    const require = createRequire("/app/package.json");
    const Database = require("better-sqlite3");

    const COMBO = "${combo}";
    const CMC = ${builtins.toJSON cmcLegs};
    const OC_FREE = ${builtins.toJSON ocFreeLegs};
    const OFF = CMC.concat(OC_FREE);
    const PEAK = CMC;

    const ZEN_MODELS_URL = "https://opencode.ai/zen/v1/models";
    const UA = "opencode/1.18.31";
    const BASE62 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

    // ses_ + 12 lowercase hex (time-derived) + 14 base62 - the documented
    // shape the Zen free tier accepts. The model list endpoint is free and
    // does not consume completion quota.
    function mintSession() {
      const v = ~((BigInt(Date.now()) * 0x1000n) + 1n);
      let hex = "";
      for (let i = 5; i >= 0; i--) {
        hex += ((v >> BigInt(8 * i)) & 0xffn).toString(16).padStart(2, "0");
      }
      const bytes = crypto.randomBytes(14);
      let tail = "";
      for (let i = 0; i < 14; i++) tail += BASE62[bytes[i] % 62];
      return "ses_" + hex + tail;
    }

    async function fetchZenModelIds() {
      const session = mintSession();
      try {
        const res = await fetch(ZEN_MODELS_URL, {
          headers: {
            Authorization: "Bearer public",
            "User-Agent": UA,
            "x-opencode-session": session,
            "x-opencode-client": "cli",
            "x-opencode-request": "msg_" + session.slice(4),
          },
          signal: AbortSignal.timeout(15000),
        });
        if (!res.ok) throw new Error("HTTP " + res.status);
        const j = await res.json();
        const list = Array.isArray(j) ? j : j.data || [];
        return new Set(list.map((m) => m.id));
      } catch (e) {
        return null; // network error -> skip pruning, never break the swap
      }
    }

    const db = new Database("/app/data/db/data.sqlite");
    const row = db.prepare("SELECT models FROM combos WHERE name = ?").get(COMBO);
    if (!row) { console.error("combo not found"); process.exit(1); }

    let cur = JSON.parse(row.models);
    const same = (a, b) => a.length === b.length && a.every((x, i) => x === b[i]);

    // --- phase 1: prune allowlist legs that no longer exist upstream ----------
    const zenIds = await fetchZenModelIds();
    if (zenIds) {
      const dead = OC_FREE.filter((m) => !zenIds.has(m.slice(3))); // strip "oc/"
      if (dead.length > 0) {
        const pruned = cur.filter((m) => !dead.includes(m));
        if (pruned.length !== cur.length) {
          db.prepare("UPDATE combos SET models = ?, updatedAt = ? WHERE name = ?")
            .run(JSON.stringify(pruned), new Date().toISOString(), COMBO);
          console.log(`pruned ''${dead.length} dead upstream leg(s): ''${dead.join(", ")}`);
          cur = pruned;
        }
      }
    } else {
      console.log("upstream model sweep unavailable; skipping prune");
    }

    // --- phase 2: window swap ------------------------------------------------
    // A list is recognized as OFFPEAK when its cmc prefix equals the canonical
    // cmc block and every extra entry is an oc/ free leg (in any order/count
    // that phase 1 may have pruned). PEAK is the exact canonical cmc block.
    // Anything else is a manual dashboard edit and is left alone.
    const cmcPrefixOk =
      cur.length >= CMC.length &&
      CMC.every((m, i) => cur[i] === m) &&
      cur.slice(CMC.length).every((m) => m.startsWith("oc/"));

    let mode;
    if (same(cur, PEAK)) {
      mode = "PEAK";
    } else if (cmcPrefixOk) {
      mode = "OFFPEAK";
    } else {
      console.log("combo manually edited beyond prune scope, skipping swap: " + JSON.stringify(cur));
      process.exit(0);
    }

    // Filter the target list through the freshest upstream knowledge so a
    // retired free model never lands in the combo. The target is the OPPOSITE
    // of the current state: this one script is used by both the peak-on and
    // peak-off timers, so it always toggles.
    const target = (mode === "OFFPEAK" ? PEAK : OFF).filter(
      (m) => !zenIds || !m.startsWith("oc/") || zenIds.has(m.slice(3))
    );

    if (!same(cur, target)) {
      db.prepare("UPDATE combos SET models = ?, updatedAt = ? WHERE name = ?")
        .run(JSON.stringify(target), new Date().toISOString(), COMBO);
      console.log(`swapped ''${mode} -> ''${mode === "OFFPEAK" ? "PEAK" : "OFFPEAK"} (''${target.length} models)`);
    } else {
      console.log(`already at ''${mode} target (''${target.length} models)`);
    }
  '';

  swapScript = pkgs.writeShellScript "9router-offpeak-swap" ''
    set -euo pipefail
    STATE=/tmp/9router-combo-state
    NOW=$(date +%s)
    LAST=$([ -f "$STATE" ] && cat "$STATE" || echo 0)
    [ $((NOW - LAST)) -lt 60 ] && exit 0   # idempotent: both timers fire on boot catch-up
    echo "$NOW" > "$STATE"
    # Feed the module over stdin: the container sees only /app/data, so a
    # /nix/store path is unresolvable inside it ("Cannot find module").
    exec ${pkgs.docker}/bin/docker exec -i 9router node --input-type=module - < ${swapNode}
  '';
in
{
  systemd.services = {
    "9router-offpeak-peak-on" = {
      description = "9router: enter CommandCode peak window (strip paid deepseek + hold back free legs)";
      serviceConfig = {
        Type = "oneshot";
        User = "smolpanda";
        Group = "users";
        ExecStart = swapScript;
      };
    };
    "9router-offpeak-peak-off" = {
      description = "9router: leave CommandCode peak window (restore full list + append free legs)";
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
        OnCalendar = [ "*-*-* 07:55:00" "*-*-* 12:55:00" ];
        Persistent = true;
        Unit = "9router-offpeak-peak-on.service";
      };
    };
    "9router-offpeak-peak-off" = {
      description = "9router off-peak: leave peak window (11:05 / 17:05 WIB)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = [ "*-*-* 11:05:00" "*-*-* 17:05:00" ];
        Persistent = true;
        Unit = "9router-offpeak-peak-off.service";
      };
    };
  };
}
