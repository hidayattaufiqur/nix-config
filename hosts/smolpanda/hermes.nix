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
    environmentFiles = [ config.sops.secrets."hermes-env".path ];
    settings = {
      model.default = "opencode-go/deepseek-v4-flash";
      web.backend = "tavily";
      web.extract_backend = "tavily";
      # Vision analysis backend: OpenCode Go is the only credential on this
      # box, and minimax-m3 is the cheapest OpenCode Go model verified to
      # accept image input (glm-5.2/gpt-5.6-luna are text-only in this
      # deployment despite accepting image_url). Without this, auxiliary.vision
      # resolves to nothing and vision_analyze is dropped from sessions.
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
        free_response_channels = [ 1534949307168460862 ];
      };
    };
  };

  # Run with full access to the smolpanda home so Hermes can drive the user's
  # opencode CLI (auth in ~/.local/share/opencode) and reach git/ssh configs.
  systemd.services.hermes-agent.environment.HOME = lib.mkForce "/home/smolpanda";
  systemd.services.hermes-agent.serviceConfig.ReadWritePaths = [ "/home/smolpanda" ];

  # Restart the gateway when the generated config.yaml content changes
  # (auxiliary.vision, mcp_servers, ...). Without this, a nixos-rebuild switch
  # regenerates config.yaml but the running process never re-reads it.
  systemd.services.hermes-agent.restartTriggers = [ "/var/lib/hermes/.hermes/config.yaml" ];
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
}
