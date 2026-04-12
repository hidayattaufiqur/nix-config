{ pkgs, ... }:

# Spigot Minecraft Server Configuration
# The server is managed manually via tmux and the mc-management interface
# RCON settings must be configured in server.properties manually

{
  # Disable the default NixOS minecraft-server service
  # We use a custom Spigot server managed by mc-management
  services.minecraft-server.enable = false;
  
  # Ensure tmux is available for the management interface
  environment.systemPackages = with pkgs; [
    tmux
    jdk# Java runtime for Minecraft server
  ];
  
  # Open firewall ports
  networking.firewall.allowedTCPPorts = [ 25565 25575 ]; # Minecraft + RCON
  networking.firewall.allowedUDPPorts = [ 19132 25565 25575 ]; # Minecraft Geysher
}
