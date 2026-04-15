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

  # systemd units moved to ./systemd/mc-management.nix
}
