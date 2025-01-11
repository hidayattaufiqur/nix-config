{ pkgs, ... }:
let
  ontology-be = "/home/nixos-server/Fun/Projects/ontology-BE";
  blogablog = "/home/nixos-server/Fun/Projects/blogAblog/";
  hidayattaufiqurDev = "/home/nixos-server/Fun/Projects/hidayattaufiqur.dev/dist";
  eigen-tc = "/home/nixos-server/Fun/Projects/e-be-tc";
in
{

  systemd.services.ontology-be = {
    description = "Gunicorn instance for Nusantara Food Ontology";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "nixos-server";
      Group = "users";
      WorkingDirectory = ontology-be;
      ExecStart = "/home/nixos-server/Fun/Projects/ontology-BE/.venv/bin/gunicorn --config gunicorn.conf.py app.__init__:'create_app()'";
      Restart = "always";
      StandardOutput = "null";
      StandardError = "null";
      Environment = [ "PATH=/home/nixos-server/Fun/Projects/ontology-BE/.venv/bin" "LD_LIBRARY_PATH=${pkgs.libstdcxx5.out}/lib:${pkgs.stdenv.cc.cc.lib}/lib" ];
    };
  };

  # systemd.services.blogablog = {
  #   description = "systemd unit to run blogablog";
  #   after = [ "network.target" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     User = "nixos-server";
  #     Group = "users";
  #     WorkingDirectory = blogablog;
  #     Environment = [
  #       "PATH=/home/nixos-server/.nix-profile/bin:/etc/profiles/per-user/nixos-server/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin"
  #     ];
  #     ExecStart = "${pkgs.nodejs}/bin/npm start"; 
  #     StandardOutput = "journal";
  #     StandardError = "journal";
  #   };
  # };
    
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
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # systemd.services.eigen-tc = {
  #   description = "systemd unit to run eigen-tc API";
  #   after = [ "network.target" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     User = "nixos-server";
  #     Group = "users";
  #     WorkingDirectory = eigen-tc;
  #     Environment = [
  #       "PATH=/home/nixos-server/.nix-profile/bin:/etc/profiles/per-user/nixos-server/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin"
  #     ];
  #     ExecStart = "${pkgs.nodejs}/bin/npm start"; 
  #     StandardOutput = "journal";
  #     StandardError = "journal";
  #   };
  # };

  users.groups.gunicorn.members = [ "nginx" "nixos-server" ];
}
