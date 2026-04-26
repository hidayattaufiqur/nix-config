# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, upkgs, sops-install-secrets, modulesPath, ... }:

{
  imports =
    [ 
       # <nixpkgs/nixos/modules/virtualisation/google-compute-image.nix>

        # TODO: only import services that are needed
       ./../../services # import everything
       ./../../services/prometheus_node_exporter.nix 
       ./../../services/grafana.nix
       ./../../services/prometheus.nix

       (modulesPath + "/installer/scan/not-detected.nix")
       (modulesPath + "/profiles/qemu-guest.nix")
       ./disk-config.nix

       ./services
    ];

  networking = {
    hostName = "server"; # Define your hostname.
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
    interfaces.eth0 = { 
      useDHCP = false;
      ipv4.addresses = [ {
        address = "103.59.160.113";
        prefixLength = 24;
      } ];
    };
    defaultGateway = "103.59.160.1";
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

# Enable virtualizations
  virtualisation = {
    docker.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
   users.users.root = {
     openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOomYBKxrymgfIO1KFLc5POYxUcfO/P58ywRWJ2EwuVV nixos@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFl+CaHy7I2ix+tLbvSkBHnvRuCI2Tyma+tmpBUcpTjt hidayattaufiqur@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMoOWiNt2HdzK/2tNy0XP72ugiiYMqRtHkj3gc2rSivL hidayattaufiqur@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINPL16Sma3ichRfxFlGtFAu7Y4uKQcRzQIo4G8N4YHKQ box@Box"
     ];
   };

  security.sudo.wheelNeedsPassword = false;
   users.users.nixos-server = {
     isNormalUser = true;
     extraGroups = [ "networkmanager" "wheel" "docker" "nginx" "systemd-journal" ]; 
     packages = with pkgs; [
        postgresql  
     ];
     shell = pkgs.zsh;
     openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOomYBKxrymgfIO1KFLc5POYxUcfO/P58ywRWJ2EwuVV nixos@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFl+CaHy7I2ix+tLbvSkBHnvRuCI2Tyma+tmpBUcpTjt hidayattaufiqur@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMoOWiNt2HdzK/2tNy0XP72ugiiYMqRtHkj3gc2rSivL hidayattaufiqur@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMN+6euukSpWncbYN+wczXPi+frMcp2osbEg0zi2VUf2 9dots\hidayat.taufiqur@9D-ID-HIDAYAT"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINPL16Sma3ichRfxFlGtFAu7Y4uKQcRzQIo4G8N4YHKQ box@Box"
     ];
   };

   programs.zsh.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Linux utilities 
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
    ripgrep     btop

    ## Nix utilities
    nix-tree
    nix-index

    ## Dev apps 
    redis
    go
    gofumpt
    lazygit
    rustup    perl
    gpp
    gcc
    docker
    docker-compose
    # jdk    nodejs_20
    neovim 
    # google-cloud-sdk
    python3
    nginx
    ollama
    upkgs.opencode
    upkgs.github-copilot-cli

    ## Python packages
    # python311Packages.pip
    # python311Packages.virtualenv
    # python311Packages.gunicorn
    # python311Packages.python-magic
    # python311Packages.flask
    # python312Packages.lxml
    # python312Packages.certbot
    uv

    ## LSP servers
    basedpyright
    nil
    golangci-lint
    gopls
    lua-language-server
  ];

  # Firewall configured in hosts/server/services/firewall.

  environment.variables = {
    SUDO_EDITOR = "nvim";
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    MANPAGER = "nvim +Man!";
  };
  
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Cap systemd journal size to prevent log accumulation
  services.journald.extraConfig = ''
    SystemMaxUse=300M
    SystemKeepFree=1G
    MaxRetentionSec=2week
  '';

  # Nix configuration settings
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      # Free space automatically when nix store grows large
      min-free = 1073741824;   # trigger GC when < 1 GB free
      max-free = 5368709120;   # free up to 5 GB when triggered
      trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
      substituters = [ "https://cache.nixos.org" "https://nix-community.cachix.org" ];
    };
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 3d";
    };
  }; 


  # Package overlays
  nix.package = pkgs.nixVersions.stable;


  # SOPS secrets management
  # Override the package so it's built against nixpkgs-unstable (has
  # buildGo125Module); nixos-24.11 only ships up to buildGo124Module.
  sops.package = sops-install-secrets;
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  system.stateVersion = "23.11"; # Did you read the comment?
}
