{ upkgs, pkgs, ... }:
let 
  packages = with pkgs; [
    freerdp 
  ];

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
  ./../../services/sunshine.nix 
  ./../../services/interception_tool.nix

  ./hardware-configuration
  ];
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.nixos = {
    isNormalUser = true;
    description = "swift";
    extraGroups = [ "networkmanager" "wheel" "docker" "logiops" "wireshark"];
    packages = unstablePackages ++ packages;
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOomYBKxrymgfIO1KFLc5POYxUcfO/P58ywRWJ2EwuVV nixos@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFl+CaHy7I2ix+tLbvSkBHnvRuCI2Tyma+tmpBUcpTjt hidayattaufiqur@gmail.com"
    ];
  };

  nixpkgs.overlays = [
    (final: prev: {
      postman = prev.postman.overrideAttrs(old: rec {
        version = "20230716100528";
        src = final.fetchurl {
          url = "https://web.archive.org/web/${version}/https://dl.pstmn.io/download/latest/linux_64";
          sha256 = "sha256-svk60K4pZh0qRdx9+5OUTu0xgGXMhqvQTGTcmqBOMq8=";
          name = "${old.pname}-${version}.tar.gz";
        };
      });
    })
  ];
}
