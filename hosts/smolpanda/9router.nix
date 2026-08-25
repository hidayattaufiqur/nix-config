# 9Router service configuration (Docker-based)
{ config, lib, pkgs, ... }:

{
  # Secret lives in secrets-extra.yaml (agent-editable, no root needed).
  sops.secrets."9router-initial-password" = {
    sopsFile = ../../secrets/secrets-extra.yaml;
  };
  sops.templates."9router.env" = {
    content = "INITIAL_PASSWORD=${config.sops.placeholder."9router-initial-password"}";
  };

  # Persistent data dir (survives container rm/run cycles). The image has no
  # VOLUME and /app/data lives in the container's writable layer, which docker rm
  # destroys. Bind-mount a host dir so provider connections + api keys persist.
  systemd.tmpfiles.rules = [
    "d /var/lib/9router/data 0755 root root -"
  ];

  # Systemd service for 9router via Docker
  # NOTE: --rm and --restart are incompatible in docker, let systemd handle restarts
  systemd.services."9router" = {
    description = "9Router AI Model Router (Docker)";
    after = [ "network.target" "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      EnvironmentFile = config.sops.templates."9router.env".path;
      ExecStartPre = "-${pkgs.docker}/bin/docker rm -f 9router";
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name 9router --network host --env INITIAL_PASSWORD -v /var/lib/9router/data:/app/data -v ${./9router-custom-server.js}:/app/custom-server.js:ro decolua/9router";
      ExecStop = "-${pkgs.docker}/bin/docker stop 9router";
      Restart = "always";
      RestartSec = 10;
    };
  };
}
