{ config, pkgs, ... }: 

{
  home.username = "nixos-box"; 
  home.homeDirectory = "/home/nixos-box";

  imports = [
    (import ../../home-manager/programs/git.nix)
    (import ../../home-manager/programs/zsh.nix)
    (import ../../home-manager/programs/rofi.nix)
    (import ../../home-manager/programs/tmux.nix)
    (import ../../home-manager/programs/nvim/nvim.nix)
    (import ../../home-manager/programs/alacritty/alacritty.nix)
  ];

  programs.fzf = {
    enable = true; 
    enableZshIntegration = true; 
  };

  home.stateVersion = "23.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
