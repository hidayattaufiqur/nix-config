{ config, pkgs, ... }:
let
  role = config.services.server-role;
in
{
  systemd.services.fno-interactor = {
    description = "FNO Interactor dev server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      User = role.user;
      Group = "users";
      WorkingDirectory = "${role.homeDir}/Fun/Projects/fno-interactor";
      Environment = [
        "PATH=${pkgs.nodejs}/bin:${role.homeDir}/.nix-profile/bin:/etc/profiles/per-user/${role.user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin"
      ];
      ExecStart = ''
        ${pkgs.nodejs}/bin/npm run dev -- --port 5000 --host 0.0.0.0
      '';
      # Restart = "on-failure";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
