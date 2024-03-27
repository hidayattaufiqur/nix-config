{ config, pkgs, ... }: 

{
  home.username = "nixos"; 
  home.homeDirectory = "/home/nixos";

  home.stateVersion = "23.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
