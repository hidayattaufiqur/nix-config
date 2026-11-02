{ config, ... }:
let
  role = config.services.server-role;
  projectDir = "${role.homeDir}/Fun/Projects/tasks2notion";
in
{
  systemd.services.tasks2notion = {
    description = "Google Tasks to Notion tasks sync";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];

    serviceConfig = {
      # Type=oneshot is only safe if the run is guaranteed to terminate. The
      # intent is passed as an argv flag (--once), NOT as an env var: the
      # app's own .env is loaded via EnvironmentFile, which systemd applies
      # AFTER Environment=, so `RUN_ONCE=false` there used to win and turn
      # this oneshot into a never-exiting poll loop that wedged the systemd
      # job queue and blocked nixos-rebuild switch (card t_aeba0fc4).
      Type             = "oneshot";
      User             = role.user;
      Group            = "users";
      WorkingDirectory = projectDir;
      EnvironmentFile  = "${projectDir}/.env";
      UnsetEnvironment = [ "RUN_ONCE" ];
      ExecStart        = "${projectDir}/.venv/bin/python src/main.py --once";
      # Belt and braces: a hung run now dies as a clean failure instead of
      # parking a job forever. Restart= stays at the oneshot default (no) —
      # the timer is the retry policy. NOTE: a start also fails fast (203)
      # whenever the venv's interpreter is GC'd from the store, so this needs
      # a gcroot: /home/smolpanda/.local/state/nix-gcroots/tasks2notion-python311
      TimeoutStartSec  = 300;
      StandardOutput   = "journal";
      StandardError    = "journal";
    };
  };

  # Timer deliberately NOT enabled: the Google refresh token is dead
  # (invalid_grant, expired 2026-08-21), so every fire fails and fills the
  # journal with a traceback. Re-enable `wantedBy = [ "timers.target" ]`
  # once d9s has re-run the OAuth consent flow and
  # `systemctl start tasks2notion` exits 0.
  systemd.timers.tasks2notion = {
    description = "Run tasks2notion sync every minute";
    timerConfig = {
      OnBootSec       = "1min";
      OnUnitActiveSec = "1min";
      Persistent      = true;
      Unit            = "tasks2notion.service";
    };
  };
}
