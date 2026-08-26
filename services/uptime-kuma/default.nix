# uptime-kuma — DISABLED 2026-08-26 (OOM declutter, user decision). User
# thought it was already off; it was running since Aug 14. Stop + remove the
# import (workloads.nix) + the public nginx proxy (public.nix). Re-enable by
# restoring the import + services.uptime-kuma block if uptime monitoring is
# wanted again.

{ config, lib, pkgs, ... }:

{
  services.uptime-kuma = {
    enable = false;
    settings = {
      UPTIME_KUMA_HOST = "127.0.0.1";
      UPTIME_KUMA_PORT = "3001";
      UPTIME_KUMA_DB_TYPE = "postgres";
      UPTIME_KUMA_DB_HOSTNAME = "localhost";
      UPTIME_KUMA_DB_PORT = "5432";
      UPTIME_KUMA_DB_NAME = "uptime_kuma";
      UPTIME_KUMA_DB_USERNAME = "uptime_kuma";
      # UPTIME_KUMA_DB_PASSWORD injected at runtime via sops-managed EnvironmentFile
    };
  };

  # Render the DB password into a systemd EnvironmentFile at activation time
  sops.secrets."uptime-kuma/dbPassword" = {};
  sops.templates."uptime-kuma.env" = {
    content = ''
      UPTIME_KUMA_DB_PASSWORD=${config.sops.placeholder."uptime-kuma/dbPassword"}
    '';
  };

  systemd.services.uptime-kuma.serviceConfig.EnvironmentFile =
    config.sops.templates."uptime-kuma.env".path;
}
