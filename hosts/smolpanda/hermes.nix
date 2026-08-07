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
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f /home/smolpanda/.hermes/rebuild-trigger";
      ExecStart = "${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake /home/smolpanda/nix-config#smolpanda";
    };
  };

  sops.secrets."hermes-env" = { };
}
