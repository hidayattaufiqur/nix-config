{ pkgs, upkgs, ... }: {
   programs.neovim = {
     enable = true;
     vimAlias = true;
     viAlias = true;
     defaultEditor = true;
     package = upkgs.neovim-unwrapped;
     plugins = with upkgs.vimPlugins; [
      { plugin = auto-save-nvim; type = "lua"; config = builtins.readFile ./custom/configs/autosave.lua; }
      { plugin = vim-wakatime; type = "lua"; }
      (nvim-treesitter.withPlugins (p: with p; [
        lua typescript javascript json html css scss yaml toml rust go gomod gosum nix proto python bash c cpp java graphql tsx markdown sql dockerfile todotxt cmake astro
      ] ++ pkgs.lib.optional (p ? tmux) tmux))
     ];
   };
   xdg.configFile.nvim = {
     source = pkgs.stdenv.mkDerivation {
       name = "cracked-nvchad-nvim0.12";
       src = pkgs.fetchFromGitHub {
         owner = "hidayattaufiqur";
         repo = "cracked.nvchad";
         rev = "e14fdf57970b80d89bcd67916bc77a3928b33fda";
         hash = "sha256-UGcndEnC4jibmDayho+XihmUxSO/VKkUhZK9ikpIZ9Y=";
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
