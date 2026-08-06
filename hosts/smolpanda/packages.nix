# Packages and system settings migrated from the old nixos-server host.
{ pkgs, upkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    ## Linux utilities
    jq
    mosh
    xclip
    gccNGPackages_15.libstdcxx
    ngrep
    tcpdump
    bat
    fzf
    fzf-zsh
    nmap
    busybox
    speedtest-cli
    gnumake42
    rar
    unrar
    zip
    unzip
    fastfetch
    git
    wget
    htop
    oh-my-zsh
    tree
    tldr
    cron
    ripgrep
    btop

    ## Nix utilities
    nix-tree
    nix-index

    ## Dev apps
    redis
    go
    gofumpt
    lazygit
    rustup
    perl
    gpp
    gcc
    docker
    docker-compose
    nodejs_24
    bun
    pnpm
    neovim
    python3
    nginx
    ollama
    upkgs.opencode
    upkgs.github-copilot-cli
    upkgs.claude-code
    upkgs.rtk

    ## Python
    uv

    ## LSP servers
    basedpyright
    nil
    golangci-lint
    gopls
    lua-language-server
  ];

  environment.variables = {
    SUDO_EDITOR = "nvim";
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    MANPAGER = "nvim +Man!";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      auto-optimise-store = true;
      # Free space automatically when nix store grows large
      min-free = 1073741824;   # trigger GC when < 1 GB free
      max-free = 5368709120;   # free up to 5 GB when triggered
      trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
      substituters = [ "https://nixos-cache-proxy.cofob.dev" "https://cache.nixos.org" "https://nix-community.cachix.org" ];
      trusted-substituters = [ "https://nixos-cache-proxy.cofob.dev" "https://cache.nixos.org" "https://nix-community.cachix.org" ];
    };
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 3d";
    };
  };

  # Cap systemd journal size to prevent log accumulation
  services.journald.extraConfig = ''
    SystemMaxUse=300M
    SystemKeepFree=1G
    MaxRetentionSec=2week
  '';
}
