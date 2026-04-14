{ pkgs, lib, ... }:

let
  repoDir = "/home/nixos-server/Fun/mc-management";
  envFile = "/etc/mc-management.env";
  commonPath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnugrep
    pkgs.jdk
    pkgs.nodejs_20
    pkgs.procps
    pkgs.systemd
    pkgs.watchexec
  ];
in
{
  environment.systemPackages = [
    pkgs.watchexec
    (pkgs.writeShellScriptBin "mc-backend-dev" ''
      cd ${repoDir}/management/backend
      exec ${repoDir}/management/backend/venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8080 --reload
    '')
    (pkgs.writeShellScriptBin "mc-discord-bot-dev" ''
      cd ${repoDir}/management/discord_bot
      exec ${pkgs.watchexec}/bin/watchexec \
        --watch ${repoDir}/management/discord_bot \
        --exts py \
        --restart \
        -- ${repoDir}/management/discord_bot/venv/bin/python ${repoDir}/management/discord_bot/bot.py
    '')
    (pkgs.writeShellScriptBin "mc-frontend-dev" ''
      cd ${repoDir}/management/web/frontend
      exec ${pkgs.nodejs_20}/bin/npm run dev -- --host 0.0.0.0 --port 5173
    '')
  ];

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.user == "nixos-server" &&
        action.id == "org.freedesktop.systemd1.manage-units" &&
        action.lookup("unit") == "mc-server.service"
      ) {
        return polkit.Result.YES;
      }
    });
  '';

  systemd.services.mc-backend = {
    description = "Minecraft Server Management Backend API";
    after = [ "network.target" ];
    wants = [ "mc-server.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.systemd pkgs.procps pkgs.coreutils pkgs.gnugrep pkgs.findutils pkgs.jdk ];

    serviceConfig = {
      Type = "simple";
      User = "nixos-server";
      Group = "users";
      WorkingDirectory = "${repoDir}/management/backend";
      EnvironmentFile = envFile;
      Environment = [
        "PATH=${commonPath}"
        "BACKEND_HOST=0.0.0.0"
        "BACKEND_PORT=8080"
        "SERVER_DIR=/home/nixos-server/Fun/mc-server"
        "SERVER_CONTROL_MODE=systemd"
        "MC_SERVER_SERVICE_NAME=mc-server"
        "MC_SERVER_SERVICE_SCOPE=system"
        "PYTHONUNBUFFERED=1"
      ];
      ExecStart = "${repoDir}/management/backend/venv/bin/python main.py";
      Restart = "on-failure";
      RestartSec = "5s";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.services.mc-discord-bot = {
    description = "Minecraft Server Discord Bot";
    after = [ "network.target" "mc-backend.service" ];
    wants = [ "mc-backend.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "nixos-server";
      Group = "users";
      WorkingDirectory = "${repoDir}/management/discord_bot";
      EnvironmentFile = envFile;
      Environment = [
        "PATH=${commonPath}"
        "BACKEND_API_URL=http://localhost:8080"
        "PYTHONUNBUFFERED=1"
      ];
      ExecStart = "${repoDir}/management/discord_bot/venv/bin/python bot.py";
      Restart = "on-failure";
      RestartSec = "10s";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.services.mc-web-dashboard = {
    description = "Minecraft Server Web Dashboard";
    after = [ "network.target" "mc-backend.service" ];
    wants = [ "mc-backend.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "nixos-server";
      Group = "users";
      WorkingDirectory = "${repoDir}/management/web";
      EnvironmentFile = envFile;
      Environment = [
        "PATH=${commonPath}"
        "PYTHONUNBUFFERED=1"
      ];
      ExecStart = "${repoDir}/management/backend/venv/bin/python app.py";
      Restart = "on-failure";
      RestartSec = "5s";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
