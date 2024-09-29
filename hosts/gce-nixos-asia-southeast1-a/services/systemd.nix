{ pkgs, ... }:
let 
  eigen-tc = "/home/server/Fun/Projects/e-be-tc";
in 
{
  systemd.services.eigen-tc = {
    description = "systemd unit to run eigen-tc API";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "server";
      Group = "users";
      WorkingDirectory = eigen-tc;
      Environment = [
        "PATH=/home/server/.nix-profile/bin:/etc/profiles/per-user/server/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin"
      ];
      ExecStart = "${pkgs.nodejs}/bin/npm start"; 
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
