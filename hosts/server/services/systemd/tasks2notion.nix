{ ... }:
let
  projectDir = "/home/nixos-server/Fun/Projects/tasks2notion";
in
{
  systemd.services.tasks2notion = {
    description = "Google Tasks to Notion tasks sync";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];

    serviceConfig = {
      Type             = "oneshot";
      User             = "nixos-server";
      Group            = "users";
      WorkingDirectory = projectDir;
      EnvironmentFile  = "${projectDir}/.env";
      Environment      = [ "RUN_ONCE=true" ];
      ExecStart        = "${projectDir}/.venv/bin/python src/main.py";
      StandardOutput   = "journal";
      StandardError    = "journal";
    };
  };

  systemd.timers.tasks2notion = {
    description = "Run tasks2notion sync every minute";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnBootSec       = "1min";
      OnUnitActiveSec = "1min";
      Persistent      = true;
      Unit            = "tasks2notion.service";
    };
  };
}
