{ pkgs ? null, upkgs ? null, config ? null, pinnedPkgs ? null, ... }:
{
  nurPackages = with config.nur; [
    # packages from Nur community
    repos.c0deaddict.cameractrls
  ];

  nodePackages = [
    # pkgs.nodePackages_latest.@astrojs/language-server
    upkgs.nodePackages."@astrojs/language-server"
    upkgs.nodePackages_latest.typescript-language-server
  ];

  gnomePackages = with pkgs.gnome; [
    gnome-remote-desktop
  ];

  gnomeExtensions = with upkgs.gnomeExtensions; [
    # Gnome extensions
    app-hider
    compiz-alike-magic-lamp-effect
    just-perfection
    # resource-monitor # unsupported version in Nix repo
    dash-to-dock
    blur-my-shell
    appindicator
    quick-settings-tweaker
    rounded-window-corners
    tiling-assistant
    focus # transparent inactive windows
    cronomix # a todo, pomodoro, stopwatch, and alarms app
    space-bar # i3-like workspace indicator
  ];

  # ------------------------------------------------------------------------------

  pinnedPkgs = with pinnedPkgs; [
    firefoxpwa
  ];

  unstablePackages = with upkgs; [
    # Basic apps
    whatsapp-for-linux
    spotify-player
    zotero
    vlc
    rofi-wayland
    microsoft-edge-dev
    spotify
    telegram-desktop

    # Dev apps 
    bruno
    go
    semgrep # a CLI tool for finding vulnerabalities in code
    neovim
    imhex
    vim
    zed-editor
    texlivePackages.latexmk
    atac # a TUI API client
    gobang # a TUI database manager

    # Terminal apps
    yazi # a TUI file manager
    cpu-x # cpu-z like app for linux
    geekbench
    httpstat

    # Nix utilities
    dconf2nix # a tool to convert dconf settings to nix

    # Linux utilities
    logiops
    # ueberzugpp # a dependency to draw images on terminal for yazi 

    # LSP
    basedpyright
    
    # Gnome apps
    gnome.gnome-remote-desktop
    andromeda-gtk-theme
    gnome-latex
    gnome-tweaks
    gnome3.gnome-session
  ];

  packages = with pkgs; [
    # Basic Apps
    gimp
    gnome-connections
    freerdp
    remmina
    qbittorrent
    # spotify-tui # unmaintained as per nixpkgs version 24.05
    discord
    cinnamon.nemo-with-extensions
    cinnamon.nemo-fileroller
    stremio
    gparted
    obs-studio
    calibre
    blender
    thunderbird
    brave
    blanket
    libreoffice    
    mendeley
    texliveFull
    zathura

    # Dev apps 
    sops
    gofumpt
    blackfire
    lazygit
    rustup
    redis
    perl
    vscode
    docker
    docker-compose
    jdk
    redis
    nodejs_20
    jetbrains.datagrip
    google-cloud-sdk
    python3
    commitizen
    cz-cli
    mosh # a UDP-based SSH client

    libgcc
    gcc
    gpp
    gnumake
    cmake
    gdb
    autoconf
    automake
    libtool
    pkg-config
    glibc
    glibc.dev

    # Programming languages
    libstdcxx5
    llvmPackages_18.libcxxClang

    ## Python packages
    python311Packages.pip
    python311Packages.virtualenv
    python311Packages.autopep8
    python311Packages.yapf

    ## LSP servers
    nodePackages_latest.pyright
    ccls 
    nil
    golangci-lint
    gopls
    lua-language-server

    # Linux utilities 
    jq
    ngrep
    tcpdump
    bat
    fzf
    fzf-zsh
    nmap
    busybox
    speedtest-cli
    gnumake42
    xdotool
    wtype
    wl-clipboard
    xclip
    rar 
    unrar
    zip
    unzip
    neofetch
    tlp
    git
    wget
    htop
    usbutils
    oh-my-zsh
    zsh-powerlevel10k
    tree
    tldr
    cron
    noisetorch 
    ripgrep 
    tldr
    syncthing
    btop
    xwaylandvideobridge # allow streaming from Wayland to X apps [https://blog.davidedmundson.co.uk/blog/xwaylandvideobridge/]

    # Nix utilities
    nix-tree
    nix-index
    dos2unix 

    # GTK themes 
    qgnomeplatform
    nordic
    themechanger
  ];
}
