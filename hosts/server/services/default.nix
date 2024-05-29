{ pkgs, ... }:

{
  imports = [
  ./ssh.nix
  ./psql.nix
  ./nginx.nix
  ./systemd.nix
  ./interception_tool.nix
  ];

  services.tailscale.enable = true; 
}
