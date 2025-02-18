{ ... }: {
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
      vim="nvim";
      open="nemo";
      sudoedit="sudo -e -s";
      clr="clear";
      logid="sudo systemctl start logid";
      wireshark="qt_style_override=adwaita-dark wireshark";
      virtualbox="qt_style_override=adwaita-dark VirtualBox";

      # nix command aliases
      hmupdate="home-manager build switch";
      nix-clean="time nix-store --optimise -v && nix-store --gc -v && nix-collect-garbage -v";
      config="nvim /etc/nixos/configuration.nix";
      check-storage="nix-tree";
      upgrade="time sudo nixos-rebuild switch -v";
      test-upgrade="time sudo nixos-rebuild test -v";

      upgrade-server="time nixos-rebuild switch --flake .#nixos-server --target-host gce-nix --build-host gce-nix --fast --use-remote-sudo --impure -v";
      test-upgrade-server="time nixos-rebuild test --flake .#nixos-server --target-host gce-nix --build-host gce-nix --fast --use-remote-sudo --impure -v";
      
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
