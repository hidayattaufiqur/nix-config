{ pkgs, ... }:
let
  ontology-be = "/home/nixos-server/Fun/Projects/ontology-BE";
in
{
  /**
  below are some systemd services that I want to run on startup
  */
  # stolen from Mustafa's config
  systemd.services.tailscale-autoconnect = {
    enable = true; 
    description = "Automatic connection to Tailscale";

    # make sure tailscale is running before trying to connect to tailscale
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];

    # set this service as a oneshot job
    serviceConfig.Type = "oneshot";

    # have the job run this shell script
    script = with pkgs; ''
      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi

      # otherwise authenticate with tailscale
      ${tailscale}/bin/tailscale up
    '';
  };

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

  users.groups.gunicorn.members = [ "nginx" "nixos-server" ];
}
