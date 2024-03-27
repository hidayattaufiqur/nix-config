{ config, pkgs, ... }: 

{
  home.username = "nixos-box"; 
  home.homeDirectory = "/home/nixos-box";

  imports = [
    (import ../../home-manager/programs/git.nix)
    (import ../../home-manager/programs/nvim.nix)
    (import ../../home-manager/programs/zsh.nix)
    (import ../../home-manager/programs/rofi.nix)
  ];

  # alacritty - a cross-platform, GPU-accelerated terminal emulator
  # programs.alacritty = {
  #   enable = true;
  #   # custom settings
  #   settings = {
  #     env.TERM = "xterm-256color";
  #     font = {
  #       normal = {
  #         famu
  #       }
  #       size = 12;
  #       draw_bold_text_with_bright_colors = true;
  #     };
  #     scrolling.multiplier = 5;
  #     selection.save_to_clipboard = true;
  #   };
  # };

  programs.fzf = {
    enable = true; 
    enableZshIntegration = true; 
  };

  home.stateVersion = "23.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
