{ lib, stdenv, pkgs, ... }: {
   programs.rofi = { 
    enable = true; 

    plugins = with pkgs; [
      rofi-calc
      rofi-emoji
      rofi-pass
      rofi-systemd
    ];

    # font = "IBM Plex Mono 10";
    font = "RobotoMono Nerd Font";
    theme = "dmenu";

    extraConfig = {
      show-icons = true;
      modes = [ "calc" "drun" "emoji" "filebrowser" "ssh" "run" "window" "keys" ];
      icon-theme = "Arc-X-D";
      display-drun = "Apps";
      drun-display-format = "{name}"; scroll-method = 0;
      disable-history = false;
      sidebar-mode = false;
    };
  };
}
