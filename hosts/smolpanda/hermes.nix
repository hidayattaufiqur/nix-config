{ config, lib, pkgs, upkgs, ... }:

{
  services.hermes-agent = {
    enable = true;
    user = "smolpanda";
    group = "users";
    createUser = false;
    addToSystemPackages = true;
    workingDirectory = "/home/smolpanda/hermes-work";
    extraDependencyGroups = [ "messaging" ];
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
      # - notion: Notion MCP for the Nine Dots task DBs (bc-timesheet-prep,
      #   nine-dots-task-breakdown). The token is interpolated from the Hermes
      #   .env secrets file (${VAR} placeholder) so it never lands in the nix store.
      mcp_servers = {
        microsoft_learn = {
          url = "https://learn.microsoft.com/api/mcp";
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
        ];
        # One thread per conversation, so sessions stay cleanly separated
        # per channel+thread (session keys on chat_id + thread_id).
        auto_thread = true;
        # Per-channel system prompts: each channel gets its own context.
        channel_prompts = {
          "1535217253543575603" = "This is the WORK channel (Nine Dots / D365FO). For D365FO & X++ tasks use the d365fo-architect and d365fo-developer skills; for timesheets/tasks use bc-timesheet-prep and nine-dots-task-breakdown. Communicate in English.";
          "1535217296174485545" = "This is the INFRA channel (NixOS, servers, Hermes/opencode tooling). Use nixos-* skills and declarative NixOS-native solutions; keep answers concise and operational.";
          "1535217343179923456" = "This is the PROJECTS channel (side projects and personal software).";
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
        };
      };
    };
  };

  # Run with full access to the smolpanda home so Hermes can drive the user's
  # opencode CLI (auth in ~/.local/share/opencode) and reach git/ssh configs.
  systemd.services.hermes-agent.environment.HOME = lib.mkForce "/home/smolpanda";
  systemd.services.hermes-agent.serviceConfig.ReadWritePaths = [ "/home/smolpanda" ];

  # Restart the gateway when the generated config.yaml or the merged .env
  # changes (auxiliary.vision, mcp_servers, secrets from sops, ...). Without
  # this, a nixos-rebuild switch regenerates them but the running process
  # never re-reads them.
  systemd.services.hermes-agent.restartTriggers = [
    "/var/lib/hermes/.hermes/config.yaml"
    "/var/lib/hermes/.hermes/.env"
  ];
  # First MCP startup may need to download the notion npm package via npx.
  systemd.services.hermes-agent.serviceConfig.TimeoutStartSec = "300";

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

  systemd.services.hermes-rebuild = {
    description = "Rebuild the smolpanda NixOS system from the local flake";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      WorkingDirectory = "/home/smolpanda/nix-config";
      Environment = "PATH=${pkgs.nix}/bin:${pkgs.git}/bin:${pkgs.coreutils}/bin:/run/current-system/sw/bin";
      # Snapshot the flake into a root-owned location: Nix refuses to open a
      # git repo owned by another user, so the agent's repo (/home/smolpanda)
      # must be copied before the root switch can read it.
      ExecStartPre = [
        "${pkgs.coreutils}/bin/rm -f /home/smolpanda/.hermes/rebuild-trigger"
        "${pkgs.coreutils}/bin/rm -rf /root/.hermes-rebuild-flake"
        "${pkgs.coreutils}/bin/cp -r /home/smolpanda/nix-config /root/.hermes-rebuild-flake"
        "${pkgs.coreutils}/bin/chown -R root:root /root/.hermes-rebuild-flake"
      ];
      ExecStart = "${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake /root/.hermes-rebuild-flake#smolpanda";
    };
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
