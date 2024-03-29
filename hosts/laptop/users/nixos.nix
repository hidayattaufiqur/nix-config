{ pkgs, ... }:
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.nixos = {
    isNormalUser = true;
    description = "swift";
    extraGroups = [ "networkmanager" "wheel" "docker" "logiops" "wireshark"];
    packages = with pkgs; [
    	neovim # basic necessity
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOomYBKxrymgfIO1KFLc5POYxUcfO/P58ywRWJ2EwuVV nixos@nixos"
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
