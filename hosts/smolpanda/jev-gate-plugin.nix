# jev-gate plugin source (canonical copy).
#
# The plugin dir is installed into each profile's state dir by the activation
# step in hermes.nix (plugins are CLI-managed state, not flake content), so
# this file is the SOURCE OF TRUTH. Edit here, then rebuild.
#
# What it does: replaces the human approval card for dangerous shell commands
# (approvals.mode: off) with a jev_evaluate verdict. See plugin.yaml for the
# contract and the gate's three bands.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  pluginSrc = ./jev-gate;
in
{
  environment.etc."hermes/jev-gate/plugin.yaml".source = "${pluginSrc}/plugin.yaml";
  environment.etc."hermes/jev-gate/__init__.py".source = "${pluginSrc}/__init__.py";
}
