{  pkgs, ... }: {
  programs.neovim = { 
    enable = true; 
    vimAlias = true; 
    viAlias = true;

    defaultEditor = true; 
    plugins = with pkgs.vimPlugins; [
     { 
       plugin = auto-save-nvim;
       type = "lua";
       config = builtins.readFile ./custom/configs/autosave.lua;
     }
     {
       plugin = vim-wakatime;
       type = "lua";
     }
    ];
  };
  
  xdg.configFile.nvim = {
    source = pkgs.stdenv.mkDerivation { 
      name = "tweaked nvchad";
      src = pkgs.fetchFromGitHub {
        owner = "hidayattaufiqur";
        repo = "neovimchad_tweaked";
        rev = "main"; 
        # hash has to be changed each time you want to update nvim config 
        # explanation: [https://ryantm.github.io/nixpkgs/builders/fetchers/]
        hash = "sha256-CLW7kz/D+Og0AFaKJ75Vg8VDvIt85aVUI4Uq97+HXDw=";
      };
      installPhase = ''
        mkdir -p $out
        cp -r ./* $out/
        cd $out/
        cp -r ${./custom} $out/lua/custom
      ''; 
    };
  };
}
