{ config, ... }:
let
  role = config.services.server-role;
  projectDir = "${role.homeDir}/Fun/Projects/keep2notion";
in
{
  systemd.services.keep2notion = {
    description = "Google Keep to Notion daily journal sync";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];

    serviceConfig = {
      Type             = "oneshot";
      User             = role.user;
      Group            = "users";
      WorkingDirectory = projectDir;
      EnvironmentFile  = "${projectDir}/.env";
      Environment      = [ "RUN_ONCE=true" ];
      ExecStart        = "${projectDir}/.venv/bin/python src/main.py";
      StandardOutput   = "journal";
      StandardError    = "journal";
    };
  };

  systemd.timers.keep2notion = {
    description = "Run keep2notion sync daily at 23:59";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 23:59:00";
      Persistent = true;
      Unit       = "keep2notion.service";
    };
  };
}
