{ config, pkgs, ... }:
let
  role = config.services.server-role;
  hidayattaufiqurDev = "${role.homeDir}/Fun/Projects/hidayattaufiqur.dev/dist";
in
{
  systemd.services.hidayattaufiqurDev = {
    description = "systemd unit to run personal site";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = role.user;
      Group = "users";
      WorkingDirectory = hidayattaufiqurDev;
      Environment = [
        "PATH=${role.homeDir}/.nix-profile/bin:/etc/profiles/per-user/${role.user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin"
      ];
      ExecStart = "${pkgs.nodejs_24}/bin/node server/entry.mjs"; 
      Restart = "on-failure";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  users.groups.gunicorn.members = [ "nginx" role.user ];
}
