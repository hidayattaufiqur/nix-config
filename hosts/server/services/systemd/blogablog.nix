{ pkgs, ... }:
{
  systemd.services.blogablog = {
    description = "Blogablog dev server (npm run dev)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      User = "nixos-server";
      Group = "users";
      WorkingDirectory = "/home/nixos-server/Fun/Projects/blogablog";
      Environment = [
        "PATH=/home/nixos-server/.nix-profile/bin:/etc/profiles/per-user/nixos-server/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin"
      ];
      ExecStart = ''
        ${pkgs.nodejs}/bin/npm run dev
      '';
    };
  };
}
