{ pkgs, lib, ... }:  
  
{
  home.username = "nixos-server"; 
  home.homeDirectory = "/home/nixos-server";

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

  # home.sessionVariables = {
  #   PATH = "${pkgs.nodejs}/bin:" + builtins.getEnv "PATH";
  # };
  #
  # home.activation = {
  #   installCopilotCli = lib.hm.dag.entryAfter ["writeBoundary"] ''
  #     if ! command -v copilot &> /dev/null; then
  #       ${pkgs.nodejs}/bin/npm install -g @github/copilot
  #     fi
  #   '';
  # };

  home.packages = with pkgs; [
    mosh
  ];

  home.stateVersion = "23.11";

  programs.home-manager.enable = true;
}
