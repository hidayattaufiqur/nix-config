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
    ./hermes-chromium.nix
    ./nix-ld.nix
    ./d365fo-mcp.nix
    ./jev-mcp.nix
    ./9router.nix
    # ./headroom.nix — disabled 2026-09-18: proxy held 1.3G RSS for 2.8% token saving; Hermes points straight at 9router :20128. Re-enable by uncommenting.
    # ./9router-offpeak.nix — trial-disabled 2026-10-26 (user decision, 1-week trial): deepseek-v4.1-flash
    #   GOAT allowance raised $80→$100/mo and observed burn is ~14% of it, so the peak-price-doubling
    #   swap no longer pays; GLM cache reads cost 10x deepseek's, making peak GLM legs ~4.7x a
    #   deepseek-even-at-2x request (day-worker profile: swap yields 0.38x the requests). Combo now runs
    #   one canonical list at all hours: cmc head legs + oc/ free tail. Evaluate 2026-11-02 on cost
    #   (9router usage DB) AND performance (fallback counts, latency); re-enable by uncommenting.
    ./browser-use.nix
    ./hindsight.nix
    ./dsh.nix
  ];
}
