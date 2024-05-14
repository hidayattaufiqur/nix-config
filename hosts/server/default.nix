# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

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

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  services.tailscale.enable = true; 

  # Define a user account. Don't forget to set a password with ‘passwd’.
   users.users.nixos-server = {
     isNormalUser = true;
     extraGroups = [ "networkmanager" "wheel" ]; # Enable ‘sudo’ for the user.
     packages = with pkgs; [
       tree
        neovim
        git
     ];
     openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOomYBKxrymgfIO1KFLc5POYxUcfO/P58ywRWJ2EwuVV nixos@nixos"
     ];
   };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Linux utilities $
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
    logiops
    tldr
    syncthing
    btop

    # Nix utilities
    nix-tree
    nix-index
    dos2unix 

    # Dev apps 
    go
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
  ];

  # Enable the OpenSSH daemon.
  services.openssh = { 
    enable = true; 
    extraConfig = "UseDns no";
  }; 

  # Open ports in the firewall.
   networking.firewall.trustedInterfaces = [ "tailscale0" ];
   networking.firewall.allowedTCPPorts = [ 22 80 443 3022 ];
   networking.firewall.allowedUDPPorts = [ config.services.tailscale.port 22 80 443 3022 ];

  # Remap capslock to escape 
  services.interception-tools =
    let
      itools = pkgs.interception-tools;
      itools-caps = pkgs.interception-tools-plugins.caps2esc;
    in
    {
    enable = true;
    plugins = [ itools-caps ];
    # requires explicit paths: https://github.com/NixOS/nixpkgs/issues/126681
    udevmonConfig = pkgs.lib.mkDefault ''
      - JOB: "${itools}/bin/intercept -g $DEVNODE | ${itools-caps}/bin/caps2esc -m 1 | ${itools}/bin/uinput -d $DEVNODE"
        DEVICE:
          EVENTS:
            EV_KEY: [KEY_CAPSLOCK, KEY_ESC]
    '';
  };

  environment.variables = {
    SUDO_EDITOR = "nvim";
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    MANPAGER = "nvim +Man!";
  };
  
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Nix configuration settings
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

   # Use komunix cache substituter
   settings.keep-outputs = "true";
   settings.keep-derivations = "true";
   settings.substituters = [ "https://cache.komunix.org/" "https://nix-community.cachix.org" ];
  }; 

  boot.supportedFilesystems = [ "ntfs" ];

  # Grant sudo access without password for specific commands
  security.sudo.configFile = '' 
    nixos-box ALL = NOPASSWD: /sbin/halt, /sbin/reboot, /sbin/poweroff
    nixos ALL = NOPASSWD: /sbin/halt, /sbin/reboot, /sbin/poweroff, /run/current-system/sw/bin/reboot
  '';
  security.polkit.enable = true;
  
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

  # Package overlays 
  nix = { 
    package = pkgs.nixFlakes; 
    extraOptions = "experimental-features = nix-command flakes";
  };

  system.stateVersion = "23.11"; # Did you read the comment?
}

