{ pkgs ? null, upkgs ? null, config ? null, ... }:
rec
{
  nurPackages = with config.nur; [
    # packages from Nur community
    repos.c0deaddict.cameractrls
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
  ];

  unstablePackages = with upkgs; [
    # Dev apps 
    go
    semgrep
  ];

  packages = with pkgs; [
    # Basic Apps
    qbittorrent
    spotify-tui
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
    gofumpt
    lazygit
    postman
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
    neovim 
    vim
    google-cloud-sdk
    python3

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
    tcpdump
    bat
    fzf
    fzf-zsh
    nmap
    busybox
    speedtest-cli
    gnumake42
    xdotool
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
    logiops
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
    # andromeda-gtk-theme # still in unstable channel
    themechanger
  ];
}
