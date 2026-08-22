{ config, lib, pkgs, upkgs, ... }:

let
  # ── Worker gateways (per-profile systemd services) ──────────────────────
  # The 6 worker profiles each run their own gateway so they can connect to
  # Discord as their own bot (mastermind = default profile, managed by
  # services.hermes-agent above). Each service runs the same `hermes` bash
  # wrapper as the mastermind (which exports HERMES_BUNDLED_PLUGINS etc.), but
  # scoped to the worker's HERMES_HOME via `--profile`.
  hermesPkg = config.services.hermes-agent.package;
  # janus = security/code-review worker (renamed from security-reviewer,
  # merged with the retired d365fo-reviewer 2026-08-14).
  # Worker profiles are named after the AGENT (atlas, janus, dossier, nix,
  # pandr, eris), not the role. Exception: Hermes the mastermind runs from the
  # module-managed default profile dir (/var/lib/hermes/.hermes).
  workerProfiles = [
    "atlas"
    "dossier"
    "nix"
    "janus"
    "pandr"
    "eris"
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
    };
    serviceConfig = {
      Type = "simple";
      User = "smolpanda";
      Group = "users";
      WorkingDirectory = "/var/lib/hermes/.hermes/profiles/${name}";
      ExecStart = "${hermesPkg}/bin/hermes --profile ${name} gateway run";
      Restart = "always";
      RestartSec = "5";
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
    extraDependencyGroups = [ "messaging" "anthropic" ];
    extraPackages = [ upkgs.opencode ];
    environmentFiles = [
      config.sops.secrets."hermes-env".path
      config.sops.secrets."hermes-extra".path
    ];
    settings = {
      # Global model: opencode-go relay (deepseek-v4-flash verified against
      # https://opencode.ai/zen/go/v1). The WORK channel is overridden to
      # Copilot via discord.channel_overrides below — Copilot is WORK-ONLY
      # (company resource; never used for home/infra/projects channels).
      model.default = "opencode-go/deepseek-v4-flash";
      # Mastermind reasoning effort: max for the orchestrator/CEO profile;
      # workers default to high (set per-profile in their config.yaml).
      agent.reasoning_effort = "max";
      # Clarify (Discord interactive input) window: user decision 2026-08-16.
      # 15 min to answer (900s), 5 min warning nudge (300s), then the agent
      # proceeds with the recommended default instead of hanging for an hour.
      clarify_timeout = 900;
      gateway_timeout_warning = 300;
      # AgentRouter (https://agentrouter.org) — OpenAI + Anthropic-Messages endpoints.
      # Additive providers; models: gpt-5.6-sol, claude-opus-4-8, claude-opus-5.
      providers = {
        agentrouter-openai = {
          api = "https://agentrouter.org/v1";
          name = "AgentRouter OpenAI";
          key_env = "AGENTROUTER_API_KEY";
          transport = "chat_completions";
          default_model = "gpt-5.6-sol";
          models = [ "gpt-5.6-sol" ];
          # AgentRouter requires a Claude-CLI client fingerprint (UA + chains)
          # alongside the Bearer key; plain curl/Hermes UA gets 401. Mirrors
          # ~/.config/opencode/plugins/agentrouter-headers.js.
          extra_headers = {
            "User-Agent" = "claude-cli/1.0.108 (external, cli)";
            "anthropic-version" = "2023-06-01";
            "anthropic-beta" = "claude-code-20250219,oauth-2025-04-20";
            "anthropic-dangerous-direct-browser-access" = "true";
            "x-app" = "cli";
            "x-stainless-lang" = "js";
            "x-stainless-package-version" = "0.55.1";
            "x-stainless-os" = "Windows";
            "x-stainless-arch" = "x64";
            "x-stainless-runtime" = "node";
            "x-stainless-runtime-version" = "v22.0.0";
          };
        };
        agentrouter-claude = {
          api = "https://agentrouter.org";
          name = "AgentRouter Claude";
          key_env = "AGENTROUTER_API_KEY";
          transport = "anthropic_messages";
          default_model = "claude-opus-5";
          models = [ "claude-opus-4-8" "claude-opus-5" ];
          extra_headers = {
            "User-Agent" = "claude-cli/1.0.108 (external, cli)";
            "anthropic-version" = "2023-06-01";
            "anthropic-beta" = "claude-code-20250219,oauth-2025-04-20";
            "anthropic-dangerous-direct-browser-access" = "true";
            "x-app" = "cli";
            "x-stainless-lang" = "js";
            "x-stainless-package-version" = "0.55.1";
            "x-stainless-os" = "Windows";
            "x-stainless-arch" = "x64";
            "x-stainless-runtime" = "node";
            "x-stainless-runtime-version" = "v22.0.0";
          };
        };
        opencode-zen = {
          api = "https://opencode.ai/zen/v1";
          name = "OpenCode Zen";
          key_env = "OPENCODE_GO_API_KEY";
          transport = "chat_completions";
          default_model = "big-pickle";
          models = [ "big-pickle" "hy3-free" "mimo-v2.5-free" "deepseek-v4-flash-free" ];
        };
      };
      # Agnostic failover: if opencode-go (primary) rate-limits/errors mid-turn,
      # prefer Zen free models first, then restore primary next turn.
      fallback_providers = [
        { provider = "opencode-zen"; model = "big-pickle"; }
        { provider = "agentrouter-claude"; model = "claude-opus-5"; }
        { provider = "agentrouter-openai"; model = "gpt-5.6-sol"; }
      ];
      # Mastermind orchestration: the default profile is the CEO. It needs the
      # kanban toolset so it can decompose goals and route cards to the worker
      # profiles (atlas, dossier, nix, janus, pandr,
      # devils-advocate). Workers get the kanban tools
      # auto-injected by the dispatcher; only the orchestrator opts in here.
      toolsets = [ "hermes-cli" "kanban" ];
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
      # Vision analysis backend: personal opencode-go minimax-m3, GLOBAL.
      # Hermes has no per-channel aux vision, and Copilot must stay
      # work-only, so vision is personal in every channel (user decision).
      # minimax-m3 is the cheapest OpenCode Go model verified to accept
      # image input (glm-5.2/gpt-5.6-luna are text-only in this deployment).
      auxiliary.vision = {
        provider = "opencode-go";
        model = "minimax-m3";
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
        # Copilot is WORK-ONLY: the work channel (and its auto-threads,
        # which inherit via parent_id lookup) runs on Copilot; every other
        # channel stays on the personal opencode-go/deepseek stack.
        # Threads created in a channel inherit the parent channel's override.
        channel_overrides = {
          "1535217253543575603" = {   # work
            provider = "copilot";
            model = "claude-sonnet-4.6";
          };
          "1537124050546204824" = {   # upskilling
            provider = "copilot";
            model = "claude-sonnet-4.6";
          };
        };
      };
    };
  };

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
}
