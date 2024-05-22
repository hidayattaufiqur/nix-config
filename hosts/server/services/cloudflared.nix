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
      "[TUNNEL ID]" = {
        credentialsFile = "${config.users.users.nixos-server.home}/.cloudflared/.json";
        default = "http_status:404";
      };
    };
  };
}
