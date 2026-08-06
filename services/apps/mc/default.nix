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

  # systemd unit moved to ./systemd/mc.nix
}
