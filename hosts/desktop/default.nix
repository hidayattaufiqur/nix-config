{ upkgs, pkgs, lib, ... }:
let 
 unstablePackages = with upkgs; [
   # geekbench
   # darktable
   # rawtherapee
   # lmstudio

   neovim
   opencode
 ];

 packages = with pkgs; [
    # Gamiiingg
    # lutris
    protonup-qt

    # dev 
    postgresql
    # gephi
    # protege

    # linux utilities
    radeontop
    glxinfo
    nvtopPackages.amd

    # media 
    # davinci-resolve
    droidcam
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        droidcam-obs
      ];
    })
 ];
in
{
  imports = [ # Include the results of the hardware scan.
  ../../configuration.nix 
  ./../../services/psql.nix
  ./../../services/ssh.nix 
  ./../../services/redis.nix
  ./../../services/sunshine.nix
  ./../../services/tailscale.nix
  ./../../services/interception_tool.nix

  ./hardware-configuration
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

  nixpkgs.config.permittedInsecurePackages = [
      "electron-12.2.3"
      "steam"
      "steam-original"
      "steam-run"
  ];

  
  # nixpkgs.config.allowUnfreePredicate = upkgs: builtins.elem (lib.getName upkgs) [
  #     "davinci-resolve"
  # ];

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

  virtualisation.waydroid.enable = true;

  # Autologin for the desktop user
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "nixos-box";
  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;
}
