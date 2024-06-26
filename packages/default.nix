{ pkgs ? null, upkgs ? null, config ? null, ... }:
rec
{
  nurPackages = with config.nur; [
    # packages from Nur community
    repos.c0deaddict.cameractrls
  ];

  nodePackages = with pkgs; [
    # pkgs.nodePackages_latest.@astrojs/language-server
    pkgs.nodePackages."@astrojs/language-server"
  ];

  gnomePackages = with pkgs.gnome; [
    gnome-remote-desktop
  ];

  gnomeExtensions = with pkgs.gnomeExtensions; [
    # Gnome extensions
    app-hider
    compiz-alike-magic-lamp-effect
    just-perfection
    resource-monitor # unsupported version in Nix repo
    dash-to-dock
    blur-my-shell
    appindicator
    quick-settings-tweaker
    rounded-window-corners
    tiling-assistant
    hide-top-bar
    peek-top-bar-on-fullscreen
  ];

  unstablePackages = with upkgs; [
    # Basic Apps
    whatsapp-for-linux

    # Dev apps 
    bruno
    go
    semgrep
    neovim
    vim
    httpstat
    imhex

    # Nix utilities
    dconf2nix

    # Linux utilities
    logiops
    rofi-wayland

    # LSP
    basedpyright
    
    # Gnome
    gnome.gnome-remote-desktop
    andromeda-gtk-theme
  ];

  packages = with pkgs; [
    # Basic Apps
    gimp
    gnome3.gnome-session
    gnome-connections
    freerdp
    remmina
    qbittorrent
    # spotify-tui # unmaintained as per nixpkgs version 24.05
    telegram-desktop
    discord
    cinnamon.nemo
    stremio
    gparted
    obs-studio
    calibre
    blender
    thunderbird
    brave
    spotify
    blanket
    libreoffice    
    mendeley
    zotero

    # Dev apps 
    sops
    gofumpt
    blackfire
    lazygit
    rustup
    redis
    perl
    vscode
    gpp
    gcc9
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

    # Programming languages
    libstdcxx5
    llvmPackages_18.libcxxClang

    ## Python packages
    python311Packages.pip
    python311Packages.virtualenv

    ## LSP servers
    nodePackages_latest.pyright
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
