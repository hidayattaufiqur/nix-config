{ pkgs, ... }:

let
  ontology-be = "/home/nixos-server/Fun/Projects/ontology-BE";
in
{
  # services.nginx = {
  #   enable = true;
  #   recommendedProxySettings = true;
  #   recommendedGzipSettings = true;
  #   logError = "stderr debug";
  #   virtualHosts."ontology-api.hidayattaufiqur.dev" = {
  #     root = ontology-be;
  #     locations."/" = {
  #       proxyPass = "http://127.0.0.1:5000";
  #       extraConfig = ''
  #         X-Real-IP $remote_addr;
  #         X-Forwarded-For $proxy_add_x_forwarded_for;
  #         X-Forwarded-Proto $scheme;
  #       '';
  #     };
  #   };
  # };
  systemd.services.ontology-be = {
    description = "Ontology API";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "nixos-server";
      Group = "users";
      WorkingDirectory = ontology-be;
      ExecStart = "/home/nixos-server/Fun/Projects/ontology-BE/.venv/bin/flask run";
      # Restart = "always";
      StandardOutput = "journal";
      StandardError = "journal";
      Environment = [ "PATH=/home/nixos-server/Fun/Projects/ontology-BE/.venv/bin" "LD_LIBRARY_PATH=${pkgs.libstdcxx5.out}/lib:${pkgs.stdenv.cc.cc.lib}/lib" ];
    };
  };

  systemd.services.gunicorn = {
    description = "Gunicorn instance";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "nixos-server";
      Group = "users";
      WorkingDirectory = ontology-be;
      ExecStart = "/home/nixos-server/Fun/Projects/ontology-BE/.venv/bin/gunicorn --preload --workers 3 --bind 0.0.0.0:5000 app:app";
      # Restart = "always";
      StandardOutput = "journal";
      StandardError = "journal";
      Environment = [ "PATH=/home/nixos-server/Fun/Projects/ontology-BE/.venv/bin" "LD_LIBRARY_PATH=${pkgs.libstdcxx5.out}/lib:${pkgs.stdenv.cc.cc.lib}/lib" ];
    };
  };

  environment.systemPackages = with pkgs; [
    libstdcxx5
    # python3
    # python3Packages.gunicorn
  ];

  users.groups.gunicorn.members = [ "nginx" "nixos-server" ];
}
