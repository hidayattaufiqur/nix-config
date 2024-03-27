{ pkgs, ... }:
{
  users.users.nixos-box = { 
     isNormalUser = true;
     description = "box";
     extraGroups = [ "networkmanager" "wheel" "docker" "logiops" "wireshark"];
     packages = with pkgs; [
     	neovim # basic necessity
     ];
     shell = pkgs.zsh;
     openssh.authorizedKeys.keys = [
       "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOomYBKxrymgfIO1KFLc5POYxUcfO/P58ywRWJ2EwuVV nixos@nixos"
     ];
  };
}
