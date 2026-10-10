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
    ./jev-mcp.nix
    ./9router.nix
    # ./headroom.nix — disabled 2026-09-18: proxy held 1.3G RSS for 2.8% token saving; Hermes points straight at 9router :20128. Re-enable by uncommenting.
    ./9router-offpeak.nix
    ./browser-use.nix
    ./hindsight.nix
  ];
}
