{ pkgs, ... }:

{
  imports = [
  ./ssh.nix
  ./psql.nix
  ./nginx.nix
  ./systemd.nix
  ./tailscale.nix
  ./interception_tool.nix
  ];
}
