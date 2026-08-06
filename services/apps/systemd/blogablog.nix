{ config, pkgs, ... }:
let
  role = config.services.server-role;
in
{
  systemd.services.blogablog = {
    description = "Blogablog dev server (npm run dev)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.nodejs pkgs.bash ];

    serviceConfig = {
      User = role.user;
      Group = "users";
      WorkingDirectory = "${role.homeDir}/Fun/Projects/blogablog";
      # Environment = [
      #   "PATH=${role.homeDir}/.nix-profile/bin:/etc/profiles/per-user/${role.user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin"
      # ];
      ExecStart = "${pkgs.nodejs}/bin/npm run dev";
    };
  };
}
