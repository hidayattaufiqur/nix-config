{ lib, ... }: 
{
  programs.alacritty = {
    enable = true;
    settings = lib.attrsets.recursiveUpdate(import ./default-settings.nix) {};
  };
}
