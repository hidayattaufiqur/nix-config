{ pkgs, ... }:

# Spigot Minecraft Server Configuration
# The server is managed as a dedicated systemd service.
# RCON settings must still be configured in server.properties manually.

{
  # Disable the default NixOS minecraft-server service
  # We use a custom Spigot server with the mc-management interface.
  services.minecraft-server.enable = false;
  
  # Java runtime for the custom server service.
  environment.systemPackages = with pkgs; [
    jdk
  ];
  
  # Open firewall ports
  networking.firewall.allowedTCPPorts = [ 25565 25575 ]; # Minecraft + RCON
  networking.firewall.allowedUDPPorts = [ 19132 25565 25575 ]; # Minecraft Geysher

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
