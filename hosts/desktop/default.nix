{ upkgs, pkgs, lib, ... }:
let 
 unstablePackages = with upkgs; [
   darktable
   rawtherapee
 ];

 packages = with pkgs; [
    # Gamiiingg
    lutris
    protonup-qt

    # dev 
    postgresql
    gephi

    # linux utilities
    radeontop
    glxinfo
    nvtop-amd

    # basic
    firefox
    neovim 
        
    # media 
    davinci-resolve
 ];
in
{
  imports = [ # Include the results of the hardware scan.
  ./hardware-configuration
  ../../configuration.nix 
  ];

  users.users.nixos-box = { 
     isNormalUser = true;
     description = "box";
     extraGroups = [ "networkmanager" "wheel" "docker" "logiops" "wireshark"];
     packages = unstablePackages ++ packages;

     shell = pkgs.zsh;
     openssh.authorizedKeys.keys = [
       "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOomYBKxrymgfIO1KFLc5POYxUcfO/P58ywRWJ2EwuVV nixos@nixos"
     ];
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  nixpkgs.config.permittedinsecurepackages = [
      "electron-12.2.3"
      "steam"
      "steam-original"
      "steam-run"
  ];

  
  nixpkgs.config.allowUnfreePredicate = upkgs: builtins.elem (lib.getName upkgs) [
      "davinci-resolve"
  ];

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (final: prev: {
      steam = prev.steam.override ({ extraPkgs ? pkgs': [], ... }: {
        extraPkgs = pkgs': (extraPkgs pkgs') ++ (with pkgs'; [
          libgdiplus
        ]);
      });

      postman = prev.postman.overrideAttrs(old: rec {
        version = "20240205183313";
        src = final.fetchurl {
          url = "https://web.archive.org/web/${version}/https://dl.pstmn.io/download/latest/linux_64";
          sha256 = "sha256-svk60K4pZh0qRdx9+5OUTu0xgGXMhqvQTGTcmqBOMq8=";

          name = "${old.pname}-${version}.tar.gz";
        };
      });
    })
  ];

  # Enable postgresql service
  services.postgresql = {
    enable = true;
    # ensureDatabases = [ "mydatabase" ];
    enableTCPIP = true;
    # port = 5432;
    # authentication = pkgs.lib.mkOverride 10 ''
    #   #...
    #   #type database DBuser origin-address auth-method
    #   # ipv4
    #   host  all      all     127.0.0.1/32   trust
    #   # ipv6
    #   host all       all     ::1/128        trust
    # '';
  };

  virtualisation.waydroid.enable = true;
}
