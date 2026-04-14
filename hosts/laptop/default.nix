{ upkgs, pkgs, ... }:
let 
  unstablePackages = with upkgs; [
    neovim
  ];
in
{
  imports = [
  ./../../configuration.nix
  ./../../services/psql.nix
  ./../../services/ssh.nix
  ./../../services/tailscale.nix
  # ./../../services/sunshine.nix 
  ./../../services/interception_tool.nix

  ./hardware-configuration
  ];
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.nixos = {
    isNormalUser = true;
    description = "swift";
    extraGroups = [ "networkmanager" "wheel" "docker" "logiops" "wireshark"];
    packages = unstablePackages;
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOomYBKxrymgfIO1KFLc5POYxUcfO/P58ywRWJ2EwuVV nixos@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFl+CaHy7I2ix+tLbvSkBHnvRuCI2Tyma+tmpBUcpTjt hidayattaufiqur@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMN+6euukSpWncbYN+wczXPi+frMcp2osbEg0zi2VUf2 9dots\hidayat.taufiqur@9D-ID-HIDAYAT"
    ];
  };

  nixpkgs.overlays = [];

  # Autologin for the laptop user
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "nixos";
  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Disable closing lid to suspend
  services.logind.extraConfig = ''
    HandleLidSwitch=ignore
  '';
}
