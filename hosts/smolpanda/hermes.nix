{ config, lib, pkgs, upkgs, ... }:

let
  # ── Worker gateways (per-profile systemd services) ──────────────────────
  # The 6 worker profiles each run their own gateway so they can connect to
  # Discord as their own bot (mastermind = default profile, managed by
  # services.hermes-agent above). Each service runs the same `hermes` bash
  # wrapper as the mastermind (which exports HERMES_BUNDLED_PLUGINS etc.), but
  # scoped to the worker's HERMES_HOME via `--profile`.
  hermesPkg = config.services.hermes-agent.package;
  # Worker profiles are named after the AGENT (atlas, janus, dossier, nix,
  # pandr, eris), not the role. Exception: Hermes the mastermind runs from
  # the module-managed default profile dir (/var/lib/hermes/.hermes).
  # janus = security/code-review + QA/merge/deploy worker (profile dir renamed
  # back from gate-keeper 2026-08-27, undoing the 2026-08-23 symlink rename;
  # the janus/gate-keeper pair was a single identity with two names).
  # 2026-08-26 (OOM declutter, user decision): nix and pandr gateways
  # disabled — user talks to eris (this bot), atlas (research/plan),
  # and dossier (docs) directly. Their profile dirs stay; re-add by restoring
  # the name here. 2026-08-27: eris gateway under review (1.5GiB RSS — see
  # gateway-usage audit); janus/nix/pandr/gate-keeper are dispatch-only.
  workerProfiles = [
    "atlas"
    "dossier"
  ];
  # ── Ponytail plugin state (intentionally imperative) ────────────────────
  # ponytail (github.com/DietrichGebert/ponytail) is a per-turn ruleset
  # injector, NOT an MCP server — its MCP wrapper cannot enforce every turn,
  # so it lives as a hermes CLI-managed plugin in each profile's state dir,
  # not under settings.mcp_servers or extraPlugins. Intended state per
  # profile (mirror: ~/.config/opencode/agent/<name>.md embeds + global
  # ~/.config/opencode/AGENTS.md):
  #   hermes (mastermind) installed, NOT enabled
  #   dossier             not installed
  #   atlas               installed + enabled
  #   nix                 installed + enabled
  #   janus               installed + enabled
  #   pandr               installed + enabled
  #   eris                installed + enabled
  # Install/enable with:
  #   HERMES_HOME=/var/lib/hermes/.hermes[/profiles/<name>] \
  #     hermes plugins install DietrichGebert/ponytail --enable
  # Ruleset source of truth: ~/Fun/Projects/MCP/ponytail.
  workerGateway = name: {
    description = "Hermes Agent Gateway - ${name} worker";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ hermesPkg pkgs.git pkgs.coreutils ];
    environment = {
      HOME = "/home/smolpanda";
      HERMES_HOME = "/var/lib/hermes/.hermes/profiles/${name}";
      # Browser tool binary for worker gateways (playwright E2E checks).
      AGENT_BROWSER_EXECUTABLE_PATH = "/home/smolpanda/.local/bin/chromium-fhs";
    } // lib.optionalAttrs (name == "atlas") {
      # Restart-forcing token, same trick as hermes-agent below: a profile's
      # config.yaml is written at activation, so restartTriggers never hashes
      # the new content and THIS gateway would keep the old model in memory.
      # Bump the epoch whenever atlas/config.yaml or atlas/SOUL.md changes
      # (2026-09-30: v1; 2026-10-10: v2 = evidence-first SOUL.md steer).
      # Changing the value rewrites the unit env, which is what makes
      # switch-to-configuration restart this gateway.
      # 2026-10-22: v2 -> v3 to load the jev-gate plugin (plugins load once
      # per process) together with the approvals.policy changes.
      HERMES_CONFIG_EPOCH = "3";
    }
    // lib.optionalAttrs (name == "dossier") {
      # Same restart-forcing trick, dossier's own counter (runs at v0: unset).
      # 2026-10-22: set to v3 to load the jev-gate plugin + approvals changes.
      HERMES_CONFIG_EPOCH = "3";
    };
    serviceConfig = {
      Type = "simple";
      User = "smolpanda";
      Group = "users";
      WorkingDirectory = "/var/lib/hermes/.hermes/profiles/${name}";
      ExecStart = "${hermesPkg}/bin/hermes --profile ${name} gateway run";
      Restart = "always";
      RestartSec = "5";
      # Atlas needs the TW read-only Azure DevOps PAT; dossier needs
      # ORVIX_TOKEN for the jev MCP server (2026-10-10). Both therefore read
      # the broad hermes-extra secret now, which also hands dossier the AZDO
      # PATs / KB passwords / VERCEL token it does not need.
      # ponytail: one env blob for both profiles — split ORVIX_TOKEN into its
      # own sops key (EnvironmentFile per profile) if that boundary matters
      # more than one extra key to rotate.
      EnvironmentFile = lib.optionals (name == "atlas" || name == "dossier") [
        config.sops.secrets."hermes-extra".path
      ];
      UMask = "0007";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [
        "/home/smolpanda"
        "/var/lib/hermes"
      ];
      PrivateTmp = true;
      TimeoutStartSec = "300";
      # Cgroup memory caps (2026-08-27 harness audit): eris crept to 1.5GiB
      # before restart revealed 611MiB baseline. Soft ceiling triggers reclaim;
      # hard ceiling kills before RAM starvation cascades to other services.
      MemoryHigh = "800M";
      MemoryMax = "1200M";
    };
    restartTriggers = [
      "/var/lib/hermes/.hermes/profiles/${name}/config.yaml"
      "/var/lib/hermes/.hermes/profiles/${name}/.env"
      "/var/lib/hermes/.hermes/profiles/${name}/SOUL.md"
      # Plugin sources: plugins are loaded ONCE per gateway process, so a
      # changed plugin file would not take effect until a manual restart.
      # Hashing the plugin dir makes the switch restart the gateway instead.
      "/var/lib/hermes/.hermes/profiles/${name}/plugins"
    ];
  };
in
{
  services.hermes-agent = {
    enable = true;
    user = "smolpanda";
    group = "users";
    createUser = false;
    addToSystemPackages = true;
    workingDirectory = "/home/smolpanda/hermes-work";
    extraDependencyGroups = [ "messaging" "anthropic" "hindsight" ];
    extraPackages = [ upkgs.opencode ];
    environmentFiles = [
      config.sops.secrets."hermes-env".path
      config.sops.secrets."hermes-extra".path
      config.sops.templates."hermes-9router.env".path
      config.sops.templates."hermes-hindsight.env".path
    ];
    settings = {
      # Global model: CommandCode Provider API — fully qualified
      # provider/model so bare 'ox-alpha' never fuzzy-matches onto
      # opencode-go's catalog (which has ox-alpha-free) for NEW sessions.
      # Work + upskilling channels stay Copilot via channel_overrides below.
      # Primary traffic routes via 9router (local OpenAI-compat proxy).
      # model changes happen in the 9router Combo without editing hermes.nix.
      model.default = "hermes-agent";
      # provider MUST be set explicitly: slash specs are model strings, never
      # providers (hermes_cli/models.py only parses `provider:model` colon
      # syntax). With no model.provider, resolve_requested_provider falls
      # through to the auto env-key loop (hermes_cli/auth.py) which matched
      # OPENCODE_GO_API_KEY first -> every hermes-agent turn 400'd
      # (x-opencode-session) and burned a fallback. Fixed for the default
      # profile + all worker profiles 2026-10-11 (task t_b919d7ee).
      model.provider = "9router";
      # model.default = "opencode-go/deepseek-v4-flash";
      model.context_length = 1000000;

      # Mastermind reasoning effort: max for the orchestrator/CEO profile;
      # workers default to high (set per-profile in their config.yaml).
      agent.reasoning_effort = "high";
      # Per-model Luna overrides: request high reasoning; Copilot's live
      # catalog advertises ["minimal","low","medium","high"] and the provider
      # clamps verbatim — "max" would downgrade to "medium", so "high" is the
      # safe ceiling that always lands at the highest available level.
      agent.reasoning_overrides = {
        "gpt-6-luna" = "high";
        "gpt-5.6-luna" = "high";
      };
      # Mastermind skill disable-list (2026-08-27 harness audit): 10 bundled
      # skills with zero use/view since install (2026-08-13) — design &
      # entertainment shelfware that never fires for the orchestrator role.
      # Focus trim only (index cost ~0.1-0.3% of context); re-enable by
      # removing a name here. Counted proof: .usage.json use_count=0,
      # view_count=0 for every entry below.
      skills.disabled = [
        "claude-design"
        "comfyui"
        "himalaya"
        "manim-video"
        "openhue"
        "p5js"
        "popular-web-designs"
        "sketch"
        "songwriting-and-ai-music"
        "touchdesigner-mcp"
      ];
      # Clarify (Discord interactive input) window: user decision 2026-08-16.
      # 15 min to answer (900s), 5 min warning nudge (300s), then the agent
      # proceeds with the recommended default instead of hanging for an hour.
      clarify_timeout = 900;
      gateway_timeout_warning = 300;

      # Dangerous-command approval policy. User decision 2026-10-22: approval
      # cards were timing out silently on Discord (the prompt arrives as a
      # message with no @mention, so he never gets a ping), and a timeout is
      # fail-closed -> the command is denied and the turn stalls. Fix is
      # three-layered:
      #   1. allowlist the prompt CLASSES that fire constantly on routine infra
      #      work, so no card is raised at all (`hermes approvals suggest`
      #      mines this from real history);
      #   2. a long timeout, so a genuinely novel prompt survives him being away;
      #   3. deny rules as the irreversible floor - they survive --yolo and
      #      `mode: off`, unlike the allowlist.
      # mode stays `smart` (NOT off): low-risk auto-approves, genuinely
      # dangerous auto-denies, only uncertain cases escalate to a card.
      approvals = {
        # OFF per user decision 2026-10-22: no more approval cards (they
        # arrive on Discord without a ping and fail closed at the timeout,
        # stalling the turn). The safety net is the JEV GATE PLUGIN
        # (plugins/jev-gate) - jev_evaluate decides per command whether the
        # call is safe, and blocks it when it is not.
        mode = "off";
        # Kept for the plugin's own escalation path and for any surface that
        # still uses the human gate.
        timeout = 1800;
        # Preserved from the previous live config (he clicked "Always Approve"
        # on the /clear /new /reset modal at some point). Declared here so a
        # nix-driven config regen does not silently re-enable that modal.
        destructive_slash_confirm = false;
        # Never-run floor. Deny rules fire BEFORE the yolo / mode=off bypass
        # (tools/approval.py::_match_user_deny_rule), so these still hold
        # with mode off. They are matched with fnmatch against the WHOLE
        # command, so they must be narrow:
        #   * "git push --force*" - exact prefix, no false positives.
        #   * "curl*|*sh" style globs are TOO BROAD: fnmatch matches the
        #     whole string, so "*curl*|*sh*" fired on an unrelated command
        #     that merely contained "curl", a pipe, and the letters "sh"
        #     somewhere later. These variants anchor on the pipe-to-shell
        #     shape instead ("... | sh" at the end of the command).
        deny = [
          "git push --force*"
          "git push --force-with-lease*"
          "*| sh"
          "*| bash"
          "*| zsh"
          "*| ksh"
          "*|sh"
          "*|bash"
          "*|zsh"
          "*|ksh"
        ];
      };

      # TOP-LEVEL key, not approvals.command_allowlist. The docs put the
      # permanent allowlist at config root, which is where "always approve"
      # writes it. Nesting it under approvals. is silently ignored - verified
      # with `hermes approvals test`: nested -> still ask-approval.
      #
      # Two matcher rules to know when editing this list
      # (tools/approval.py::_command_matches_permanent_allowlist):
      #   * a pattern with no glob wildcard must match the command EXACTLY;
      #   * a command containing a shell operator (&&, ||, ;, |, <, >, `,
      #     newline, $(...) ) never matches the allowlist at all - it is
      #     considered too compound. So allowlist the SIMPLE command, and
      #     expect a compound one to still prompt.
      #   * fnmatch globs do not cross "/" (fnmatch.translate maps * to .*),
      #     so "rm -rf /tmp/*" does NOT cover "rm -rf /tmp/a/b" - hence the
      #     extra one- and two-level entries below.
      command_allowlist = [
        # Class keys mined from 90d of approval history, i.e. things he has
        # already approved by hand hundreds of times.
        "script execution via -e/-c flag" # 531x
        "shell command via -c/-lc flag" # 2x - wraps systemd-run/heredocs
        "command parser limit or malformed executable payload" # 19x
        "stop/restart system service" # 11x - infra deploys

        # /tmp scratch cleanup. Scoped GLOBS on purpose, NOT the
        # "delete in root path" class key: that key matches any leading-slash
        # path, so allowlisting it would also silently permit
        # `rm -rf /home/...` and `rm -rf /var/...`.
        "rm -f /tmp/*"
        "rm -rf /tmp/*"
        "rm -f /tmp/*/*"
        "rm -rf /tmp/*/*"
        "rm -rf /tmp/*/*/*"

        # The nix eval/build wrapper used on every rebuild. The eval MUST run
        # outside the gateway's memory cgroup or it thrashes and kills the
        # turn, so this wrapper is on the critical path.
        "systemd-run --user --scope *"
      ];

      # jev-gate plugin: the approval gate that replaced the human card
      # (approvals.mode: off). Plugins are opt-in via plugins.enabled; the
      # plugin dir itself lives in the profile state dir (CLI-managed, like
      # ponytail) and is NOT flake-owned.
      plugins.enabled = [ "jev-gate" ];

      security = {
        allow_data_training_tiers_noninteractive = true;
      };

      # CommandCode Provider API — primary inference for all crew.
      # Endpoints: OpenAI-compat at https://api.commandcode.ai/provider/v1 (chat_completions)
      #            Anthropic-compat at https://api.commandcode.ai/provider/v1/messages
      # Key: COMMANDCODE_API_KEY (in hermes-extra sops secret).
      # Primary model: meta/muse-spark-1.2-contributor (smarter + cheaper than deepseek)
      # Fallback model: deepseek/deepseek-v4-flash.
      # AgentRouter removed — too unreliable in Hermes harness (EmptyStreamError + 401s).
      # Use opencode CLI for AgentRouter if ever needed.
      providers = {
        commandcode = {
          api = "https://api.commandcode.ai/provider/v1";
          name = "CommandCode";
          key_env = "COMMANDCODE_API_KEY";
          transport = "chat_completions";
          models = [ "meta/muse-spark-1.3-contributor" "deepseek/deepseek-v4.1-flash" "xiaomi/mimo-v2.5" ];
        };
        opencode-go = {
          api = "https://opencode.ai/go/v1";
          name = "OpenCode Go";
          key_env = "OPENCODE_GO_API_KEY";
          transport = "chat_completions";
          models = [ "meta/muse-spark-1.2-contributor" "deepseek/deepseek-v4-flash" ];
        };
        "9router" = {
          api = "http://127.0.0.1:20128/v1";   # direct 9router — headroom proxy disabled 2026-09-18 (1.3G RSS for 2.8% saving, not worth it)
          name = "9Router";
          key_env = "NINE_ROUTER_API_KEY";
          transport = "chat_completions";
          default_model = "hermes-agent";
          models = [ "hermes-agent" ];
        };
      };
      # Dashboard via Tailscale (100.64.254.88) - password gate for non-loopback bind
      dashboard.basic_auth = {
        username = "hidayattaufiqur";
        password_hash = "scrypt$16384$8$1$dnqw18ACuX7e/Vri87pRIg==$KvBE3wLmfCZVllMFJYGD1wT1fqONdta4XSQZIVkbquo=";
      };
      # Declarative fallback chain (mirrors runtime config.yaml): the gateway
      # walks this when the primary model fails. 9router/hermes-agent first —
      # it is the reliable path that answers every mastermind turn.
      fallback_providers = [
        { provider = "9router"; model = "hermes-agent"; }
        { provider = "commandcode"; model = "meta/muse-spark-1.3-contributor"; }
        { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; }
      ];
      # Mastermind orchestration: the default profile is the CEO. It needs the
      # kanban toolset so it can decompose goals and route cards to the worker
      # profiles (atlas, dossier, nix, gate-keeper, pandr,
      # devils-advocate). Workers get the kanban tools
      # auto-injected by the dispatcher; only the orchestrator opts in here.
      toolsets = [ "hermes-cli" "kanban" ];
      memory.provider = "hindsight";
      memory.hindsight = {
        mode = "cloud";
        api_url = "http://127.0.0.1:8888";
        bank_id = "hermes-agent";
        recall_budget = "mid";
      };
      # Kanban: dispatch inside the gateway (default), orchestrator is the
      # default profile (empty orchestrator_profile falls back to it).
      kanban = {
        dispatch_in_gateway = true;
        orchestrator_profile = "";
        auto_decompose = true;
      };
      # Give slow remote MCP servers (microsoft_learn ~10s handshake) time to
      # land in the first-turn tool snapshot; the join returns instantly when
      # discovery completes, so fast servers cost ~0.
      mcp_discovery_timeout = 15;
      web.backend = "tavily";
      web.extract_backend = "tavily";
      # Discord gateway tool progress verbosity (2026-09-30 user request:
      # set display.tool_progress to "new" for Discord).
      # `new` = tool indicator only when the tool changes (quieter than default `all`).
      display.platforms.discord.tool_progress = "new";
      # Vision analysis backend: commandcode Muse Spark 1.3 contributor (vision-capable).
      # 9router oc/muse-spark-1.2-contributor-free returns empty content on vision (HTTP 200 content:"") — pinned to commandcode paid vision.
      auxiliary.vision = {
        provider = "commandcode";
        model = "meta/muse-spark-1.3-contributor";
      };
      # MCP servers ported from the user's opencode setup (~/.config/opencode/opencode.json).
      # - microsoft_learn: official Microsoft Learn MCP (remote, no auth) — used by the
      #   d365fo-developer / d365fo-troubleshooter skills.
      #   NOTE: the endpoint is SLOW from this box (~10s cold handshake), so the gateway
      #   defaults (discovery 1.5s, keepalive 180s) don't fit it. Tuned below:
      #   connect_timeout 30 / timeout 90 / keepalive_interval 30 + global
      #   mcp_discovery_timeout 15. A wedged default-timeout connection made
      #   gateway restarts hang on MCP shutdown (2026-08-07) — these knobs fix that.
      # - notion: Notion MCP for the Nine Dots task DBs (bc-timesheet-prep,
      #   nine-dots-task-breakdown). The token is interpolated from the Hermes
      #   .env secrets file (${VAR} placeholder) so it never lands in the nix store.
      mcp_servers = {
        microsoft_learn = {
          url = "https://learn.microsoft.com/api/mcp";
          connect_timeout = 30;
          timeout = 90;
          keepalive_interval = 30;
        };
        notion = {
          command = "npx";
          args = [ "-y" "@notionhq/notion-mcp-server" ];
          env = {
            NOTION_TOKEN = "\${NOTION_TOKEN}";
          };
        };
      };
      discord = {
        require_mention = true;
        # Channels where the bot responds without @mention.
        # Home (general) + work + infra + projects channels.
        free_response_channels = [
          1534949307168460862   # Home (general)
          1535217253543575603   # work
          1535217296174485545   # infra (nix, servers, tooling)
          1535217343179923456   # projects
          1537124050546204824   # upskilling (D365FO program)
        ];
        # One thread per conversation, so sessions stay cleanly separated
        # per channel+thread (session keys on chat_id + thread_id).
        auto_thread = true;
        # Per-channel system prompts: each channel gets its own context.
        channel_prompts = {
          "1535217253543575603" = "This is the WORK channel (Nine Dots / D365FO). For D365FO & X++ tasks use the d365fo-architect and d365fo-developer skills; for timesheets/tasks use bc-timesheet-prep and nine-dots-task-breakdown. Communicate in English.";
          "1535217296174485545" = "This is the INFRA channel (NixOS, servers, Hermes/opencode tooling). Use nixos-* skills and declarative NixOS-native solutions; keep answers concise and operational.";
          "1535217343179923456" = "This is the PROJECTS channel (side projects and personal software).";
          "1537124050546204824" = "This is the UPSKILLING channel (D365FO technical upskilling program). Hands-on: modules M0-M9 of the curriculum (D365FO_Upskilling_Curriculum.md), real perf challenges with before/after measurements. Use the d365fo-architect skill and the ~/d365fo-src source mirror; keep answers practical and session-oriented.";
        };
        # Copilot GPT-6 Luna high-reasoning for work/atlas (2026-09-30 user
        # request: gpt-5.6-luna -> gpt-6-luna); upskilling stays on
        # gpt-5.6-luna. Threads auto-inherit the parent channel's override
        # via gateway _get_channel_override parent_id lookup — no per-thread
        # config needed. Global agent.reasoning_effort = "high" covers both;
        # per-model override pins max reasoning where catalog allows it.
        channel_overrides = {
          "1535217253543575603" = {   # work
            provider = "copilot";
            model = "gpt-6-luna";
          };
          "1537124050546204824" = {   # upskilling
            provider = "copilot";
            model = "gpt-6-luna";
          };
          "1535315824485732423" = {   # atlas-agent
            provider = "copilot";
            model = "gpt-6-luna";
          };
        };
      };
    };
  };

  # ── Atlas profile-level evidence-first steer ────────────────────────────
  # SOUL.md is Hermes's only per-profile instruction slot that is always in
  # the system prompt (slot #1); worker-profile config.yaml is CLI-owned and
  # has no instruction key, and nothing else in this flake generates worker
  # profile state. So this flake OWNS atlas/SOUL.md: edit
  # hosts/smolpanda/atlas-SOUL.md, not the profile dir (activation overwrites
  # it on every switch, and the epoch bump above restarts the gateway).
  # Content = the shared Hindsight policy + the D365FO evidence-first steer.
  system.activationScripts.hermes-atlas-soul = lib.stringAfter [ "users" ] ''
    install -o smolpanda -g users -m 0660 -D ${./atlas-SOUL.md} /var/lib/hermes/.hermes/profiles/atlas/SOUL.md
  '';

  # Dossier's SOUL.md was hand-written in the profile dir and unmanaged until
  # now (2026-10-10); hosts/smolpanda/dossier-SOUL.md is its current content
  # plus the jev steer, so the flake OWNS it from here on.
  system.activationScripts.hermes-dossier-soul = lib.stringAfter [ "users" ] ''
    install -o smolpanda -g users -m 0660 -D ${./dossier-SOUL.md} /var/lib/hermes/.hermes/profiles/dossier/SOUL.md
  '';

  # ── jev-gate plugin install ──────────────────────────────────────────────
  # The approval gate that replaced the human card (approvals.mode: off).
  # Plugins live in the profile's state dir, which the CLI owns, so the flake
  # copies the source in on every switch. Without this, settings.plugins.enabled
  # = [ "jev-gate" ] would point at a missing dir after a profile reset.
  # Installed for every profile that runs a gateway (default + workers).
  system.activationScripts.hermes-jev-gate = lib.stringAfter [ "users" ] ''
    for prof in "" profiles/atlas profiles/dossier; do
      dest="/var/lib/hermes/.hermes/$prof/plugins/jev-gate"
      mkdir -p "$dest"
      install -o smolpanda -g users -m 0660 -D ${./jev-gate/plugin.yaml} "$dest/plugin.yaml"
      install -o smolpanda -g users -m 0660 -D ${./jev-gate/__init__.py} "$dest/__init__.py"
    done
  '';

  # ── jev-gate wiring in worker profiles ───────────────────────────────────
  # Worker profile config.yaml files are CLI-owned (the flake only generates
  # the default profile's via services.hermes-agent.settings), so the gate is
  # wired in by a targeted TEXT edit (NOT a yaml round-trip - that would
  # reorder every key in a CLI-owned file):
  #   1. approvals.mode: 'off' + timeout: 1800 (quoted 'off' - YAML 1.1 parses
  #      a bare off as boolean False)
  #   2. plugins.enabled += jev-gate
  # Idempotent: re-running on an already-wired profile reports "already wired".
  system.activationScripts.hermes-jev-gate-worker-config =
    lib.stringAfter [ "users" "hermes-jev-gate" ] ''
      ${pkgs.python3}/bin/python3 ${./jev-gate/worker-patch.py}
    '';

  # ── Default (mastermind) + pandr SOUL: one source, two installs ──────────
  # Both were hand-written and unmanaged until 2026-10-11, and their content
  # was already byte-identical (the shared Hindsight policy), so one file
  # serves both. Why flake-owned: the rebuild-trigger knowledge
  # (`touch ~/.hermes/rebuild-trigger`, never `nixos-rebuild switch` from an
  # agent) is spread across many skills that an agent has to *choose* to load
  # at the right moment, which is why it kept getting missed. SOUL.md is slot
  # #1 of the system prompt — always in context — so pinning it here is what
  # actually raises the hit rate. Edit hosts/smolpanda/default-SOUL.md, not the
  # profile dirs (activation overwrites them; the epoch bump restarts the
  # default gateway so the new content is read).
  system.activationScripts.hermes-default-soul = lib.stringAfter [ "users" ] ''
    install -o smolpanda -g users -m 0660 -D ${./default-SOUL.md} /var/lib/hermes/.hermes/SOUL.md
    install -o smolpanda -g users -m 0660 -D ${./default-SOUL.md} /var/lib/hermes/.hermes/profiles/pandr/SOUL.md
  '';

  # Run with full access to the smolpanda home so Hermes can drive the user's
  # opencode CLI (auth in ~/.local/share/opencode) and reach git/ssh configs.
  # Worker gateways (defined at top of file): each worker profile runs its own
  # gateway systemd service so it connects to Discord as its own bot.
  # Single mkMerge so it composes with the module's own systemd.services defs.
  systemd.services = lib.mkMerge [
    (lib.mergeAttrsList (map (name: {
      "hermes-gateway-${name}" = workerGateway name;
    }) workerProfiles))
    {
      hermes-agent = {
        environment.HOME = lib.mkForce "/home/smolpanda";
        # Epoch forces gateway restart on switch (config.yaml rewrites land
        # after restartTriggers hash, so settings changes never restart it).
        # 2026-09-30: bumped 2 -> 3 for the work/atlas gpt-6-luna rollout.
        # 2026-10-11: bumped 3 -> 4 so the flake-owned default/SOUL.md (the
        # rebuild-trigger knowledge that must live in slot #1) lands in the
        # running gateway — the SOUL is written by an activation script, so
        # restartTriggers cannot hash its new content within the same switch.
        # 2026-10-22: bumped 4 -> 5 for the approvals policy (allowlist + 30m
        # timeout + deny floor) so the running gateway stops raising cards that
        # time out silently on Discord.
        # 2026-10-22 (2): bumped 5 -> 6 to restart the gateway after the
        # jev-gate plugin landed (plugins load once per process).
        environment.HERMES_CONFIG_EPOCH = "6";
        serviceConfig.ReadWritePaths = [ "/home/smolpanda" ];
        # Restart the gateway when the generated config.yaml or the merged .env
        # changes (auxiliary.vision, mcp_servers, secrets from sops, ...).
        # Without this, a nixos-rebuild switch regenerates them but the running
        # process never re-reads them.
        restartTriggers = [
          "/var/lib/hermes/.hermes/config.yaml"
          "/var/lib/hermes/.hermes/.env"
          "/var/lib/hermes/.hermes/SOUL.md"
          # Plugin sources: plugins are loaded ONCE per gateway process, so a
          # changed plugin file would not take effect until a manual restart.
          "/var/lib/hermes/.hermes/plugins"
          "/run/secrets/hermes-extra"
        ];
        serviceConfig.TimeoutStartSec = "300";
      };
      # Root rebuild trigger for the Hermes agent. The agent writes
      # /home/smolpanda/.hermes/rebuild-trigger; this .path unit sees the file
      # appear and the oneshot applies the flake as root — the agent never needs
      # sudo (its unit runs NoNewPrivileges). The service deletes the trigger
      # first so each write fires exactly one rebuild.
      hermes-rebuild = {
        description = "Rebuild the smolpanda NixOS system from the local flake";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          WorkingDirectory = "/home/smolpanda/nix-config";
          Environment = "PATH=${pkgs.nix}/bin:${pkgs.git}/bin:${pkgs.coreutils}/bin:/run/current-system/sw/bin";
          # Snapshot the flake into a root-owned location: Nix refuses to open
          # a git repo owned by another user, so the agent's repo
          # (/home/smolpanda) must be copied before the root switch can read it.
          ExecStartPre = [
            "${pkgs.coreutils}/bin/rm -f /home/smolpanda/.hermes/rebuild-trigger"
            "${pkgs.coreutils}/bin/rm -rf /root/.hermes-rebuild-flake"
            "${pkgs.coreutils}/bin/cp -r /home/smolpanda/nix-config /root/.hermes-rebuild-flake"
            "${pkgs.coreutils}/bin/chown -R root:root /root/.hermes-rebuild-flake"
          ];
          ExecStart = "${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake /root/.hermes-rebuild-flake#smolpanda";
        };
      };
    }
  ];

  # Root rebuild trigger for the Hermes agent. The agent writes
  # /home/smolpanda/.hermes/rebuild-trigger; this .path unit sees the file
  # appear and the oneshot applies the flake as root — the agent never needs
  # sudo (its unit runs NoNewPrivileges). The service deletes the trigger
  # first so each write fires exactly one rebuild.
  systemd.paths.hermes-rebuild = {
    description = "Watch for the Hermes rebuild trigger file";
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathExists = "/home/smolpanda/.hermes/rebuild-trigger";
  };

  sops.secrets."hermes-env" = { };
  # Extra Hermes secrets (NOTION_TOKEN, TAVILY_API_KEY) in their own sops file.
  # Encrypted for the host ssh key (so sops-nix decrypts it at build) AND the
  # user's age key at ~/.config/sops/age/keys.txt (so the agent can edit it
  # without root). Kept separate from hermes-env because sops CLI cannot use
  # ssh keys as age identities (sops-nix can), so edits to hermes-env would
  # require root.
  sops.secrets."hermes-extra" = {
    sopsFile = ../../secrets/secrets-extra.yaml;
  };
  sops.secrets."9router-api-key" = {
    sopsFile = ../../secrets/secrets-extra.yaml;
  };
  sops.templates."hermes-9router.env" = {
    content = "NINE_ROUTER_API_KEY=${config.sops.placeholder."9router-api-key"}";
  };
  sops.secrets."hindsight-access-key" = {
    sopsFile = ../../secrets/secrets-extra.yaml;
  };
  sops.templates."hermes-hindsight.env" = {
    content = ''
      HINDSIGHT_MODE=cloud
      HINDSIGHT_API_URL=http://127.0.0.1:8888
      HINDSIGHT_API_KEY=${config.sops.placeholder."hindsight-access-key"}
      HINDSIGHT_BANK_ID=hermes-agent
      HINDSIGHT_AUTO_RECALL=true
      HINDSIGHT_AUTO_RETAIN=true
      HINDSIGHT_RECALL_BUDGET=mid
    '';
  };
}
