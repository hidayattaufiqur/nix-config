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
      vi="nvim";
      vim="nvim";
      open="nemo";
      sudoedit="sudo -e -s";
      clr="clear";
      logid="sudo systemctl start logid";
      wireshark="qt_style_override=adwaita-dark wireshark";
      virtualbox="qt_style_override=adwaita-dark VirtualBox";

      # nix command aliases
      hmupdate="home-manager build switch";
      nix-clean="nix-store --optimise && nix-store --gc";
      config="nvim /etc/nixos/configuration.nix";
      check-storage="nix-tree";
      upgrade="sudo nixos-rebuild switch --show-trace";

      upgrade-ta-server-sg="nixos-rebuild switch --flake .#gce-nixos-asia-southeast1-b --target-host gce-nixos-asia-southeast1-b --build-host gce-nixos-asia-southeast1-b --fast --use-remote-sudo --impure --show-trace";
      upgrade-ta-server-us="nixos-rebuild switch --flake .#gce-nixos-us-central1-a --target-host gce-nixos-us-central1-a --build-host gce-nixos-us-central1-a --fast --use-remote-sudo --impure --show-trace";
      upgrade-ta-monitoring-sg="nixos-rebuild switch --flake .#gce-nixos-asia-southeast1-b-monitoring --target-host gce-nixos-asia-southeast1-b-monitoring --build-host gce-nixos-asia-southeast1-b-monitoring --fast --use-remote-sudo --impure --show-trace";

      test-upgrade-ta-server-sg="nixos-rebuild test --flake .#gce-nixos-asia-southeast1-b --target-host gce-nixos-asia-southeast1-b --build-host gce-nixos-asia-southeast1-b --fast --use-remote-sudo --impure";
      test-upgrade-ta-server-us="nixos-rebuild test --flake .#gce-nixos-us-central1-a --target-host gce-nixos-us-central1-a --build-host gce-nixos-us-central1-a --fast --use-remote-sudo --impure";
      test-upgrade-ta-monitoring-sg="nixos-rebuild test --flake .#gce-nixos-asia-southeast1-b-monitoring --target-host gce-nixos-asia-southeast1-b-monitoring --build-host gce-nixos-asia-southeast1-b-monitoring --fast --use-remote-sudo --impure";
      
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
