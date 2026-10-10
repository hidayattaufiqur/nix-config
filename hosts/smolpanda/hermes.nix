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
      HERMES_CONFIG_EPOCH = "2";
    };
    serviceConfig = {
      Type = "simple";
      User = "smolpanda";
      Group = "users";
      WorkingDirectory = "/var/lib/hermes/.hermes/profiles/${name}";
      ExecStart = "${hermesPkg}/bin/hermes --profile ${name} gateway run";
      Restart = "always";
      RestartSec = "5";
      # Atlas alone needs the TW read-only Azure DevOps PAT. Keep other worker
      # gateways outside the broad hermes-extra secret environment.
      EnvironmentFile = lib.optionals (name == "atlas") [
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
      model.default = "9router/hermes-agent";
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
        environment.HERMES_CONFIG_EPOCH = "3";
        serviceConfig.ReadWritePaths = [ "/home/smolpanda" ];
        # Restart the gateway when the generated config.yaml or the merged .env
        # changes (auxiliary.vision, mcp_servers, secrets from sops, ...).
        # Without this, a nixos-rebuild switch regenerates them but the running
        # process never re-reads them.
        restartTriggers = [
          "/var/lib/hermes/.hermes/config.yaml"
          "/var/lib/hermes/.hermes/.env"
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
