# Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, upkgs, ... }:

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

  # Enable XRDP for remote desktop
  services.xrdp = {
    enable = true;
    defaultWindowManager = "gnome-remote-desktop";
    # defaultWindowManager = "${pkgs.gnome3.gnome-session}/bin/gnome-session";
    openFirewall = true;
  };
  
  services.gnome.gnome-remote-desktop.enable = true;

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
  programs.dconf.enable = true;
  programs.java.enable = true; 
  programs.noisetorch.enable = true; 
  programs.zsh.enable = true;
  programs.wireshark = { 
    enable = true; 
    package = pkgs.wireshark;
  };
  programs.kdeconnect = {
    enable = true; 
    package = pkgs.gnomeExtensions.gsconnect;
  };

  # Enable virtualizations
  virtualisation = {
    libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
      qemu.ovmf.enable = true;
      qemu.runAsRoot = true;
    };
    docker.enable = true;
    # virtualbox.host.enable = true; # disabled due to latest kernel don't support latest version of vbox yet
    # more here: [https://github.com/NixOS/nixpkgs/issues/312336]
  };

  users.extraGroups.vboxusers.members = [ "nixos" "nixos-box" ];

  # enable nix-ld for pip and friends
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    curl
    openssl
    gcc-unwrapped
    stdenv.cc.cc
    zlib # numpy
  ];

  # Enable automatic login for the user.
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "nixos";

  # Disable closing lid to suspend
  services.logind.extraConfig = ''
    HandleLidSwitch=ignore
  '';

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
  environment.systemPackages = 
    (import ./packages { pkgs = pkgs; } ).packages 
    ++ (import ./packages { upkgs = upkgs; } ).unstablePackages
    ++ (import ./packages { pkgs = pkgs; } ).gnomePackages
    ++ (import ./packages { pkgs = pkgs; } ).gnomeExtensions
    ++ (import ./packages { config = config ; } ).nurPackages
  ;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

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
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.isInGroup("users")
          && (
            action.id == "org.freedesktop.login1.reboot" ||
            action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
            action.id == "org.freedesktop.login1.power-off" ||
            action.id == "org.freedesktop.login1.power-off-multiple-sessions"
          )
        )
      {
        return polkit.Result.YES;
      }
    })
  '';

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

  # Open ports in the firewall.
  networking.firewall = { 
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedTCPPorts = [ 22 80 3389 ];
    allowedUDPPorts = [ config.services.tailscale.port 22 80 3389 ];
  };

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
