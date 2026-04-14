{ pkgs, ... }:
let
  hidayattaufiqurDev = "/home/nixos-server/Fun/Projects/hidayattaufiqur.dev/dist";
in
{
  systemd.services.hidayattaufiqurDev = {
    description = "systemd unit to run personal site";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "nixos-server";
      Group = "users";
      WorkingDirectory = hidayattaufiqurDev;
      Environment = [
        "PATH=/home/nixos-server/.nix-profile/bin:/etc/profiles/per-user/nixos-server/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin"
      ];
      ExecStart = "${pkgs.nodejs}/bin/node server/entry.mjs"; 
      Restart = "on-failure";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  users.groups.gunicorn.members = [ "nginx" "nixos-server" ];
}
