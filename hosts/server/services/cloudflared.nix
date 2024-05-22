{ config, pkgs, ... }: 
{
  #   users.users.cloudflared = {
  #   group = "cloudflared";
  #   isSystemUser = true;
  # };
  #
  # users.groups.cloudflared = { };
  # 
  # systemd.services.my_tunnel = {
  #   wantedBy = [ "multi-user.target" ];
  #   after = [ "network-online.target" "systemd-resolved.service" ];
  #   serviceConfig = {
  #     ExecStart = "${pkgs.cloudflared}/bin/cloudflared service install";
  #     Restart = "always";
  #     User = "cloudflared";
  #     Group = "cloudflared";
  #   };
  # };

  services.cloudflared = {
    enable = true;
    user = "nixos-server";
    tunnels = {
      "417e4d65-c0e9-475c-aaab-146f910cf060" = {
        credentialsFile = "${config.users.users.nixos-server.home}/.cloudflared/.json";
        default = "http_status:404";
      };
    };
  };
}
