{ pkgs, ... }:
let
  projectDir = "/home/nixos-server/Fun/Projects/nine-dots-hours-dashboard";
  publicDir = "${projectDir}/public";
  pathEnv = "${pkgs.nodejs_24}/bin:${pkgs.python3}/bin:/run/current-system/sw/bin";
in
{
  systemd.services.nine-dots-hours-dashboard = {
    description = "Nine Dots hours dashboard static server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      User = "nixos-server";
      Group = "users";
      WorkingDirectory = projectDir;
      ExecStart = "${pkgs.python3}/bin/python -m http.server 4319 --bind 127.0.0.1 --directory ${publicDir}";
      Restart = "on-failure";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.services.nine-dots-hours-dashboard-build = {
    description = "Build embedded Nine Dots hours dashboard";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "nixos-server";
      Group = "users";
      WorkingDirectory = projectDir;
      Environment = [
        "PATH=${pathEnv}"
      ];
      ExecStart = "${pkgs.nodejs_24}/bin/npm run build";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.services.nine-dots-hours-sync = {
    description = "Sync Nine Dots hours dashboard data from Notion";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "nixos-server";
      Group = "users";
      WorkingDirectory = projectDir;
      Environment = [
        "DASHBOARD_YEAR=2026"
        "NOTION_MONTH_DB_ID=2334188b-6f6a-81e5-bfb9-f0d9604052ab"
        "OUTPUT_JSON=${publicDir}/data.json"
      ];
      ExecStart = "${pkgs.python3}/bin/python ${projectDir}/sync_months.py";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.timers.nine-dots-hours-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10m";
      OnUnitActiveSec = "1d";
      Persistent = true;
      Unit = "nine-dots-hours-sync.service";
    };
  };
}
