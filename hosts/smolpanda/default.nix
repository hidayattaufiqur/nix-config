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
    ./d365fo-mcp.nix
    ./9router.nix
    ./headroom.nix
    ./9router-offpeak.nix
    ./browser-use.nix
    ./hindsight.nix
  ];
}
