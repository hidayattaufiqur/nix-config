{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware-configuration.nix
    ./disk-config.nix
    ./base.nix
    ./packages.nix
    ./workloads.nix
    ./public.nix
    ./hermes.nix
  ];
}
