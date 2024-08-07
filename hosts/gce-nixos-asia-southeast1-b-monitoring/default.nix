# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      # ./hardware-configuration
       <nixpkgs/nixos/modules/virtualisation/google-compute-image.nix>

       ../../services/nginx.nix
       ../../services/prometheus.nix
       ../../services/grafana.nix
       ../../services/ssh.nix
       ../../services/tailscale.nix
       ../../services/psql.nix
       ../../services/ssh.nix
       ../../services/interception_tool.nix
    ];

  networking = {
    hostName = "gce-nixos-asia-southeast1-b-monitoring"; # Define your hostname.
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
    # search = [ "tailede36.ts.net" ];
    # Pick only one of the below networking options.
    # wireless.enable = true;  # Enables wireless support via wpa_supplicant.
    # networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  };

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

  # Set custom option for prometheus scrape targets
  services.prometheus = {
    ta-server-sg = [ "100.94.212.89:9002" "100.94.212.89:5000" ]; 
    personal-server = [ "100.86.186.55:9002" ];
    ta-server-us = [ "100.108.137.14:9002" "100.108.137.14:5000"  ]; 
  };

  # Enable virtualizations
  virtualisation = {
    docker.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
   users.users.root = {
     openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOomYBKxrymgfIO1KFLc5POYxUcfO/P58ywRWJ2EwuVV nixos@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFl+CaHy7I2ix+tLbvSkBHnvRuCI2Tyma+tmpBUcpTjt hidayattaufiqur@gmail.com"
     ];
   };

  security.sudo.wheelNeedsPassword = false;
   users.users.server = {
     isNormalUser = true;
     extraGroups = [ "networkmanager" "wheel" "docker" "nginx" ]; 
     packages = with pkgs; [
        postgresql  
        tree
        neovim
        git
     ];
     shell = pkgs.zsh;
     openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOomYBKxrymgfIO1KFLc5POYxUcfO/P58ywRWJ2EwuVV nixos@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFl+CaHy7I2ix+tLbvSkBHnvRuCI2Tyma+tmpBUcpTjt hidayattaufiqur@gmail.com"
     ];
   };

   programs.zsh.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Linux utilities 
    xclip
    libstdcxx5
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

    # TA experimentation tools 
    curlHTTP3
    wrk
    nghttp3
    ngtcp2
    cmake
    libbpf
    autoconf
    automake
    libtool
    gnat
    libclang

    # Nix utilities
    nix-tree
    nix-index
    dos2unix 

    # Dev apps 
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
    google-cloud-sdk
    python3
    nginx

    ## Python packages
    python311Packages.pip
    python311Packages.virtualenv
    python311Packages.gunicorn

    ## LSP servers
    nodePackages_latest.pyright
    nil
    golangci-lint
    gopls
    lua-language-server
  ];

  # Open ports in the firewall.
   networking.firewall.trustedInterfaces = [ "eth0" ];
   networking.firewall.allowedTCPPorts = [ 22 80 443 2342 5000 9001 9002 ];
   networking.firewall.allowedUDPPorts = [ config.services.tailscale.port 22 80 443 2342 ];

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

   settings.keep-outputs = "true";
   settings.keep-derivations = "true";
   settings.trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
   settings.substituters = [ "https://cache.nixos.org" "https://nix-community.cachix.org" ];
  }; 

  boot.supportedFilesystems = [ "ntfs" ];

  # Grant sudo access without password for specific commands
  security.sudo.configFile = '' 
    nixos-box ALL = NOPASSWD: /sbin/halt, /sbin/reboot, /sbin/poweroff
    nixos ALL = NOPASSWD: /sbin/halt, /sbin/reboot, /sbin/poweroff, /run/current-system/sw/bin/reboot
  '';
  security.polkit.enable = true;
  

  # Package overlays 
  nix = { 
    package = pkgs.nixFlakes; 
    extraOptions = "experimental-features = nix-command flakes";
  };

  system.stateVersion = "24.05"; # Did you read the comment?
}
