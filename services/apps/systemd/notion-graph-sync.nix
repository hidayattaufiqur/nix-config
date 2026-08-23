# notion-graph-sync — manual-first oneshot. Pulls a curated subset of the
# Notion workspace and emits a privacy-gated graph-data.json, then copies it
# into the website repo working tree so the site's normal deploy picks it up.
#
# NOT enabled and NO timer: the owner wants to eyeball the first outputs
# before scheduling. Start manually with:
#   systemctl start notion-graph-sync
{ config, pkgs, ... }:
let
  role = config.services.server-role;
  stateDir = "/var/lib/notion-graph-sync";
  siteRepoGraph = "${role.homeDir}/Fun/Projects/hidayattaufiqur.dev/public/graph-data.json";
in
{
  systemd.services.notion-graph-sync = {
    description = "Notion workspace to privacy-gated graph-data.json sync";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];

    serviceConfig = {
      Type             = "oneshot";
      User             = role.user;
      Group            = "users";
      StateDirectory   = "notion-graph-sync";
      # Env-style sops file (NOTION_TOKEN among unrelated vars). systemd reads
      # EnvironmentFile as root before dropping privileges, so root-owned 0400
      # is fine — same consumption pattern as hermes-agent's environmentFiles.
      EnvironmentFile  = config.sops.secrets."hermes-extra".path;
      ExecStart        = "${pkgs.callPackage ../../../pkgs/notion-graph-sync { }}/bin/notion-graph-sync --output ${stateDir}/graph-data.json";
      # Only runs if ExecStart exited 0 — the harmlessness gate is fail-closed,
      # so a gate failure never copies anything into the site repo.
      ExecStartPost    = "${pkgs.coreutils}/bin/install -Dm 644 ${stateDir}/graph-data.json ${siteRepoGraph}";
      StandardOutput   = "journal";
      StandardError    = "journal";
    };
  };
}
