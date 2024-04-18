{  pkgs, ... }: {
   programs.neovim = { 
     enable = true; 
     vimAlias = true; 
     viAlias = true;

     defaultEditor = true; 
     # plugins = 
     #   let 
     #     pluginGit = owner: repo: rev: sha256: pkgs.vimUtils.buildVimPlugin {
     #       pname = repo;
     #       version = rev;
     #       src = pkgs.fetchFromGitHub {
     #         owner = owner;
     #         repo = repo;
     #         rev = rev;
     #         sha256 = sha256;
     #       };
     #     };
     #
     #    config = pkgs.vimUtils.buildVimPlugin { 
     #       name = "config";
     #       src = ./config/core;
     #     };
     #
     #     keymapConfig = pkgs.vimUtils.buildVimPlugin { 
     #       name = "keymap-config";
     #       src = ./config/keymapconfig;
     #     };
     #   in 
       # with pkgs.vimPlugins; [
  #      nvchad
  #       # {
  #       #    plugin = config;
  #       #    type = "lua";
  #       #    config = builtins.readFile ./config/config.lua;
  #       # }
  #       # {
  #       #   plugin = keymapConfig;
  #       #   type = "lua";
  #       #   config = builtins.readFile ./config/keymap.lua;
  #       # }
  #       # # {
  #       # #    plugin = gitsigns-nvim;
  #       # #    type = "lua";
  #       # #    config = builtins.readFile ./config/gitsigns.lua;
  #       # # }
  #       # {
  #       #   plugin = nvim-lspconfig; 
  #       #   type = "lua";
  #       #   config = builtins.readFile ./config/lspconfig.lua;
  #       # }
  #       # { 
  #       #   plugin = conform-nvim; 
  #       #   type = "lua";
  #       #   config = ''
  #       #     opts = {
  #       #       formatters_by_ft = {
  #       #         lua = { "stylua" },
  #       #       },
  #       #     },
  #       #     require("conform").setup(opts)
  #       #   '';
  #       # }
  #       # { 
  #       #   plugin = (pluginGit "nvchad" "base46" "v2.5" "sha256-qZUnzRbqaOkLImPNezx+Xpg9ElfgQ9UMelb2Nnbsg4k=");
  #       #   type = "lua";
  #       #   config = '' 
  #       #     require("base46").load_all_highlights();
  #       #   '';
  #       # }
  #       # { 
  #       #   plugin = (pluginGit "nvchad" "ui" "v2.5" "sha256-qtoBp0bpmfJR1TeLBfzOieL/voi3XTF925P9UnmVruY=");
  #       #   type = "lua";
  #       #   config = ''
  #       #     require "nvchad"
  #       #   '';
  #       # }
  #       # {
  #       #   plugin = (nvim-treesitter.withPlugins (_: nvim-treesitter.allGrammars
  #       #   ));
  #       #   type = "lua";
  #       #   config = builtins.readFile ./config/treesitter.lua;
  #       # }
  #       # {
  #       #   plugin = nvim-cmp;
  #       #   type = "lua";
  #       #   config = builtins.readFile ./config/cmp.lua;
  #       # }
  #     ];
  # };
  # xdg.configFile.nvim = {
  #   source = pkgs.vimPlugins.nvchad.src;
  #   recursive = true;
  # };
  # home.file.nvchad_custom = {
  #   enable = true;
  #   source = ./custom;
  #   recursive = true;
  #   target = ".config/nvim/lua/custom";
  };
}
