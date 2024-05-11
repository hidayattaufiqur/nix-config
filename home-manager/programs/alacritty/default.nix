{ lib, ... }: 
{
  programs.alacritty = {
    enable = true;
    settings = lib.attrsets.recursiveUpdate(import ./default-settings.nix) {
      # font = {
      #   normal = {
      #     family = "Fira Code";
      #     style = "Regular";
      #   };
      #   bold = {
      #     family = "Fira Code";
      #     style = "Bold";
      #   };
      # };
    };
  };
}
