{ pkgs, lib, ... }:

{
  home.username = "smolpanda";
  home.homeDirectory = "/home/smolpanda";

  imports = [
    (import ../../home-manager/programs/nvim)
    (import ../../home-manager/programs/git.nix)
    (import ../../home-manager/programs/zsh.nix)
    (import ../../home-manager/programs/tmux.nix)
  ];

  programs = {
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };

  home.packages = with pkgs; [
    mosh
  ];

  home.stateVersion = "23.11";

  programs.home-manager.enable = true;
}
