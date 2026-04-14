{ config, pkgs, ... }: 
{
  services.cloudflared = {
    enable = true;
    user = "nixos-server";
    tunnels = {
      "417e4d65-c0e9-475c-aaab-146f910cf060" = {
        credentialsFile = config.sops.secrets."cloudflare/credentialsFile".path;
        default = "http_status:404";
      };
    };
  };
}
