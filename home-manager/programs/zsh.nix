{ pkgs, ... }: {
  programs.zsh = {
    enable = true;
    enableAutosuggestions = true; 
    enableCompletion = true; 
    autocd = true;
    dotDir = ".config/zsh";
    history.extended = true; 

    initExtra = ''
      bindkey '^@' autosuggest-accept;
      export PATH=$HOME/.config/rofi/scripts:$PATH
    ''; 

    shellAliases = {
      open="nemo";
      sudoedit="sudo -e -s";
      clr="clear";
      logid="sudo systemctl start logid";
      wireshark="qt_style_override=adwaita-dark wireshark";
      virtualbox="qt_style_override=adwaita-dark VirtualBox";

      # nix command aliases
      update="sudo nixos-rebuild switch";
      upgrade="sudo nix-channel --update && sudo nixos-rebuild switch";
      hmupdate="home-manager build switch";
      nix-clean="nix-store --optimise && nix-store --gc";
      config="nvim /etc/nixos/configuration.nix";
      storage="nix-tree";

      # shell aliases
      ll="ls -al";
      la="ls -a";
      l="ls -c";
      attach="tmux attach-session -t";
      cat="bat";
      hsi="cd ~/HSI/";
      fun="cd ~/Fun/";
      projects="cd ~/Fun/Projects/";
      intern="cd ~/Intern/DDB/"; 
      secondbrain="cd ~/SecondBrain/"; 
      notes="cd ~/SecondBrain/"; 

      # git aliases
      ga="git add";
      gm="git commit -a -m";
      gs="git status";
      glo="git log --oneline";
      gl="git log";
      gps="git push";
      gpl="git pull";
      gr="git restore";
      lg="lazygit";
    };
  
    # autosuggestions.highlightStyle = "fg=cyan"; 

    syntaxHighlighting.enable = true;

    oh-my-zsh = { 
      enable = true;
      theme = "agnoster";
      custom = "~/.zshrc";
    };

  };
}
