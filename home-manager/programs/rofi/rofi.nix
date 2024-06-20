{ pkgs, ... }: {
   imports = [ (import ./theme.nix) ];
   
   programs.rofi = { 
    enable = true; 

    # package = pkgs.rofi-wayland;
    location = "center";

    plugins = with pkgs; [
      rofi-calc
      rofi-emoji
      rofi-pass
      rofi-systemd
    ];

    # font = "IBM Plex Mono 10";
    font = "RobotoMono Nerd Font";
    theme = "onedark";

    extraConfig = {
      show-icons = true;
      modes = [ "calc" "drun" "emoji" "filebrowser" "ssh" "run" "window" "keys" ];
      icon-theme = "Arc-X-D";
      display-drun = "Apps";
      drun-display-format = "{name}";
      scroll-method = 0;
      disable-history = false;
      sidebar-mode = false;
      always-on-top = true;

      /* Key bindings */
      kb-mode-next = "Tab";
      kb-mode-previous = "ISO_Left_Tab";
      kb-element-next = "";
      kb-element-prev = "";
    };
  };
}
