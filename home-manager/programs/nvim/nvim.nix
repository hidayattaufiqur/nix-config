{ lib, stdenv, pkgs, ... }: {
   programs.neovim = { 
     enable = true; 
     vimAlias = true; 
     viAlias = true;

     defaultEditor = true; 
     plugins = with pkgs.vimPlugins; [ 
        # nvim-treesitter
        # elixir-tools-nvim
        # nvchad-ui
        # catppuccin-nvim
      ];
  };
}
