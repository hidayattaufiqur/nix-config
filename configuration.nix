# Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

# TODO: Modularize this 

{ config, pkgs, ... }:

{
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  networking.nameservers = [ "100.100.100.100" "1.1.1.1" "1.0.0.1" ];
  networking.search = [ "tailede36.ts.net" ];
  
  # Set your time zone.
  time.timeZone = "Asia/Jakarta";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.autoSuspend = false;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Enable programs
  programs.java.enable = true; 
  programs.noisetorch.enable = true; 
  programs.zsh.enable = true;
  programs.wireshark = { 
    enable = true; 
    package = pkgs.wireshark;
  };
  programs.kdeconnect.enable = true; 
  virtualisation.docker.enable = true;
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "nixos" "nixos-box" ];

  # enable nix-ld for pip and friends
  programs.nix-ld.enable = true;
  # programs.nix-ld.libraries = with pkgs; [
  #   gcc-unwrapped
  #   stdenv.cc.cc.lib
  #   zlib # numpy
  # ];

  # Enable automatic login for the user.
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "nixos";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  environment.variables = {
    SUDO_EDITOR = "nvim";
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    BROWSER = "brave";
    MANPAGER = "nvim +Man!";
    TERMINAL = "alacritty";
  };

  /**
  below are some systemd services that I want to run on startup
  */
  # stolen from Mustafa's config
  systemd.services.tailscale-autoconnect = {
    enable = true; 
    description = "Automatic connection to Tailscale";

    # make sure tailscale is running before trying to connect to tailscale
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];

    # set this service as a oneshot job
    serviceConfig.Type = "oneshot";

    # have the job run this shell script
    script = with pkgs; ''
      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi

      # otherwise authenticate with tailscale
      ${tailscale}/bin/tailscale up
    '';
  };

  systemd.services.logid-startup = {
    enable = true;
    description = "Automatic startup for Logitech Daemon";

    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = with pkgs; {
      ExecStart = "${logiops}/bin/logid";
      Restart = "on-failure";
    };  
  };

  systemd.services.keyboard-startup-fix = { 
    enable = true; 
    description = "Keychron enable fn keys mode";
    unitConfig = {
      Type = "simple";
    };

    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type = "oneshot";

    script = with pkgs; ''
      #!${runtimeShell}
      # check if the file exists before attempting to write to it
      if [ -e /sys/module/hid_apple/parameters/fnmode ]; then
        echo 2 > /sys/module/hid_apple/parameters/fnmode
      else
        echo "Error: /sys/module/hid_apple/parameters/fnmode does not exist" >&2
        exit 0
      fi
    '';
  };

  # Enabling systemctl start for apps that have systemd units. (refer to systemd in NixOS section on the manual).
  systemd.packages = [ pkgs.logiops ]; # Haven't found a way to make this work, yet. 

  
  #-------------------------------------------------------------------------
  # Enable redis service
  #-------------------------------------------------------------------------
  # services.redis.servers."api-talent-report".enable=true;
  # services.redis.servers."api-talent-report".port=6379;


  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Disable default Gnome apps
  environment.gnome.excludePackages = with pkgs.gnome; [
    cheese      # photo booth
    epiphany    # web browser
    gedit       # text editor
    simple-scan # document scanner
    yelp        # help viewer
    geary       # email client
    seahorse    # password manager

    gnome-characters 
    gnome-contacts
    gnome-maps 
    pkgs.gnome-connections
  ];

  environment.shellAliases = {
    "wireshark" = "QT_STYLE_OVERRIDE=Adwaita-Dark wireshark";
  }; 

  # Installing fonts
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" "RobotoMono" ]; })
  ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [		
    # Gnome extensions
    gnomeExtensions.app-hider
    gnomeExtensions.compiz-alike-magic-lamp-effect
    gnomeExtensions.just-perfection
    gnomeExtensions.resource-monitor # unsupported version in Nix repo
    gnomeExtensions.dash-to-dock
    gnomeExtensions.blur-my-shell
    gnomeExtensions.appindicator
    gnomeExtensions.quick-settings-tweaker
    gnomeExtensions.rounded-window-corners
    gnomeExtensions.tiling-assistant
    themechanger
    
    # Basic Apps
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
    lazygit
    postman
    rustup
    redis
    perl
    vscode
    go
    gpp
    gcc9
    docker
    docker-compose
    jdk
    redis
    nodejs_20
    # alacritty 
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

    # Linux utilities 
    bat
    nmap
    busybox
    speedtest-cli
    gnumake42
    xdotool
    wl-clipboard
    xclip
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

    # Nix utilities
    nix-tree
    dos2unix 

    # GTK themes 
    qgnomeplatform
    nordic
    # andromeda-gtk-theme # still in unstable channel
  ];
	
  nix = { 
    # Enable the Flakes feature and the accompanying new nix command-line tool
    settings.experimental-features = [ "nix-command" "flakes" ];

    # Enable nix auto optimise store 
    settings.auto-optimise-store = true; 
    gc = { 
     automatic = true; 
     dates = "weekly"; 
     options = "--delete-older-than- 7d";
    }; 
  }; 

  boot.supportedFilesystems = [ "ntfs" ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = { 
    enable = true; 
    extraConfig = "UseDns no";
  }; 

  services.tailscale.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
 
  # Package overlays 
  nix = { 
    package = pkgs.nixFlakes; 
    extraOptions = "experimental-features = nix-command flakes";
  };
}
