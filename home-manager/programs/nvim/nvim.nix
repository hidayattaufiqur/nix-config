{  pkgs, ... }: {
   programs.neovim = { 
     enable = true; 
     vimAlias = true; 
     viAlias = true;

     defaultEditor = true; 
     plugins = 
       let 
         pluginGit = owner: repo: rev: sha256: pkgs.vimUtils.buildVimPlugin {
           pname = repo;
           version = rev;
           src = pkgs.fetchFromGitHub {
             owner = owner;
             repo = repo;
             rev = rev;
             sha256 = sha256;
           };
         };

        config = pkgs.vimUtils.buildVimPlugin { 
           name = "config";
           src = ./config/core;
         };

         keymapConfig = pkgs.vimUtils.buildVimPlugin { 
           name = "keymap-config";
           src = ./config/keymapconfig;
         };
       in 
       with pkgs.vimPlugins; [
        {
           plugin = config;
           type = "lua";
           config = builtins.readFile ./config/config.lua;
         }
         {
           plugin = keymapConfig;
           type = "lua";
           config = builtins.readFile ./config/keymap.lua;
         }
         { 
           plugin = (pluginGit "nvchad" "base46" "v2.5" "sha256-qZUnzRbqaOkLImPNezx+Xpg9ElfgQ9UMelb2Nnbsg4k=");
           type = "lua";
           config = builtins.readFile ./config/nvconfig.lua;
         }
         { 
           plugin = (pluginGit "nvchad" "ui" "v2.5" "sha256-qtoBp0bpmfJR1TeLBfzOieL/voi3XTF925P9UnmVruY=");
           type = "lua";
           config = builtins.readFile ./config/nvconfig.lua;
         }
        # nvim-treesitter
        # elixir-tools-nvim
        # nvchad-ui
        # catppuccin-nvim
      ];
  };
}
