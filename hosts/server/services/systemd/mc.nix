{ pkgs, ... }:
{
  systemd.services.mc-server = {
    description = "Minecraft Spigot Server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "nixos-server";
      Group = "users";
      WorkingDirectory = "/home/nixos-server/Fun/mc-server";
      ExecStart = "${pkgs.jdk}/bin/java -Xmx2G -Xms1G -jar server.jar nogui";
      Restart = "on-failure";
      RestartSec = "5s";
      KillSignal = "SIGINT";
      TimeoutStopSec = "120s";
      SuccessExitStatus = [ 0 130 143 ];
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
