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

  sops.secrets."hermes-env" = { };
}
