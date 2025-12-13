{ pkgs, upkgs, ... }:
{
  services.minecraft-server = {
    enable = true;
    eula = true;
    package = upkgs.minecraft-server;

    serverProperties = {
      motd = "Bananas Minecraft Server!";
      allow-cheats = true;
      gamemode = 0;  
      difficulty = 3;
      pause-when-empty-seconds = 10000;
      online-mode = false;
      max-players = 10;
    };
  };
}
