{ config, lib, pkgs, ... }:
{
  # Enable postgresql service (shared by desktop/laptop/smolpanda hosts)
  services.postgresql = {
    enable = true;
    # pgvector plugin for the Hermes knowledge base (semantic search).
    # Same plugin set on every host that imports this module — harmless
    # where the KB isn't used. (Newer nixpkgs renamed withPlugins ->
    # withPackages.)
    package = pkgs.postgresql_17.withPackages (ps: [ ps.pgvector ]);
    ensureDatabases = [ "postgres" "uptime_kuma" ];
    ensureUsers = [
      { name = "uptime_kuma"; }
    ];
    enableTCPIP = true;
    # port = 5432;
    # authentication = pkgs.lib.mkOverride 10 ''
    #   #...
    #   #type database DBuser origin-address auth-method
    #   # ipv4
    #   host  all      all     127.0.0.1/32   trust
    #   # ipv6
    #   host all       all     ::1/128        trust
    # '';
  };
}
