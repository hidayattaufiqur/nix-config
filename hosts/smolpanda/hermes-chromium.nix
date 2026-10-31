# Headless Chromium for Hermes browser automation (2026-10-31)
#
# The browser toolset needs a CDP endpoint. Hermes' bundled agent-browser
# binary is dynamically linked and cannot exec on NixOS (stub-ld), so instead
# we run a system Chromium (from nixpkgs, statically resolvable deps) as a
# persistent headless service on port 9222, and point browser.cdp_url at it
# (set in hermes.nix settings).
#
# - Dedicated user-data-dir (~/.hermes/chrome-debug): required by Chrome 136+
#   for --remote-debugging-port to be respected; starts signed out of
#   everything (logins get added via browser_vault / cookies as needed).
# - Memory-capped: headless Chromium idles ~350-500MB; capped at 900M to
#   protect the 7.7G box. Restart on failure; no auto-restart on OOM-kill
#   loop protection needed since Hermes handles a dead CDP endpoint by
#   reporting unavailable.
{
  systemd.services.hermes-chromium = {
    description = "Headless Chromium (CDP :9222) for Hermes browser automation";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      User = "smolpanda";
      ExecStart = let
        chromium = pkgs.chromium;
      in "${chromium}/bin/chromium --headless --no-sandbox --disable-gpu --disable-dev-shm-usage --remote-debugging-port=9222 --user-data-dir=%h/.hermes/chrome-debug --no-first-run --no-default-browser-check about:blank";
      Restart = "on-failure";
      RestartSec = 5;
      # RAM guard: headless chromium peaks ~600M with several tabs.
      MemoryHigh = "700M";
      MemoryMax = "900M";
    };
  };
}
