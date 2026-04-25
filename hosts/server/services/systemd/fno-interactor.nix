{ pkgs, ... }:
{
  systemd.services.fno-interactor = {
    description = "FNO Interactor dev server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      User = "nixos-server";
      Group = "users";
      WorkingDirectory = "/home/nixos-server/Fun/Projects/fno-interactor";
      Environment = [
        "PATH=${pkgs.nodejs}/bin:/home/nixos-server/.nix-profile/bin:/etc/profiles/per-user/nixos-server/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin"
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
