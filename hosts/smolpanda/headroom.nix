# Headroom — context-compression proxy in front of 9router for Hermes.
#
# Hermes (config.yaml providers."9router") points at http://127.0.0.1:8787/v1
# instead of 9router's :20128. Headroom compresses the request (tool outputs,
# big JSON, logs) BEFORE forwarding to 9router, which still owns provider
# auth/routing. Same NINE_ROUTER_API_KEY flows through verbatim.
#
# Hindsight calls 9router directly (:20128) and is untouched — headroom only
# fronts the Hermes gateway traffic (main model, vision aux, fallbacks all
# route through the single "9router" provider → one URL flip covers all).
#
# Installed as a uv tool (headroom-ai[all], v0.37.0) into the smolpanda home —
# same pattern as browser-use.nix. The uv venv's compiled wheels need
# libstdc++.so.6 at runtime; NixOS doesn't put gcc libs on the default
# dynamic-loader path, so LD_LIBRARY_PATH points at stdenv.cc.cc.lib.
#
# ponytail: single uv-tool install + systemd unit, no Nixpkgs package.
# Upgrade path: replace with a nixpkgs/nix headroom derivation when one
# exists (the `uv tool install` pins v0.37.0; bump manually).
{ config, lib, pkgs, ... }:

let
  headroomBin = "/home/smolpanda/.local/bin/headroom";
  gccLib = "${pkgs.stdenv.cc.cc.lib}/lib";
in
{
  systemd.services.headroom = {
    description = "Headroom context-compression proxy -> 9router";
    after = [ "network.target" "9router.service" ];
    wants = [ "9router.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "smolpanda";
      Group = "users";
      ExecStart = "${headroomBin} proxy --port 8787 --host 127.0.0.1";
      Environment = [
        "OPENAI_TARGET_API_URL=http://127.0.0.1:20128/v1"
        "HEADROOM_SAVINGS_PROFILE=coding"
        "LD_LIBRARY_PATH=${gccLib}"
        "HOME=/home/smolpanda"
      ];
      Restart = "always";
      RestartSec = 10;
    };
  };
}
