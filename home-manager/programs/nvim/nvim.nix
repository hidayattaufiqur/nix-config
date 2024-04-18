{  pkgs, ... }: {
   programs.neovim = { 
     enable = true; 
     vimAlias = true; 
     viAlias = true;

     defaultEditor = true; 
  };
  xdg.configFile.nvim = {
    source = pkgs.stdenv.mkDerivation { 
      name = "tweaked nvchad";
      src = pkgs.fetchFromGitHub {
        owner = "hidayattaufiqur";
        repo = "neovimchad_tweaked";
        rev = "main"; 
        hash = "sha256-8miW/G3XVDpHPzo2oL3BlX0VpNDuflQXe6S33TMJujA=";
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
