# Hermes knowledge base (semantic search) — smolpanda only.
#
# Postgres side of the KB:
#   - hermes_kb database with pgvector
#   - hermes_kb_ingest role (write — used by the nightly sync cron)
#   - hermes_kb_read role (read-only — used by the Secretary agent)
#
# Passwords are sops secrets (secrets-extra.yaml), injected at activation by
# a oneshot service so they never land in the nix store. Write/read split:
# the Secretary's profile env only ever holds the READ password; the ingest
# password exists only in the gateway env + this oneshot.
#
# Honest caveat: smolpanda is a single-user box (smolpanda ~ root via docker
# group), and pg_hba defaults may allow localhost trust. The role split is
# defense-in-depth at the APPLICATION level (Secretary can't write because
# she never possesses the ingest credential), not a hard network boundary.
{ config, lib, pkgs, ... }:

{
  services.postgresql = {
    ensureDatabases = [ "hermes_kb" ];
    ensureUsers = [
      {
        name = "hermes_kb_ingest";
        ensureClauses = { login = true; };  # schema/tables granted via oneshot
      }
      {
        name = "hermes_kb_read";
        ensureClauses = { login = true; };
      }
    ];
    # Prefer password auth for KB roles on localhost so the write/read split
    # holds even over TCP (first-match pg_hba: these lines come before the
    # default trust rules via mkBefore).
    authentication = lib.mkBefore ''
      host  hermes_kb  hermes_kb_ingest  127.0.0.1/32  scram-sha-256
      host  hermes_kb  hermes_kb_read    127.0.0.1/32  scram-sha-256
      host  hermes_kb  hermes_kb_ingest  ::1/128       scram-sha-256
      host  hermes_kb  hermes_kb_read    ::1/128       scram-sha-256
    '';
  };

  # One-time + idempotent init: extension, passwords, grants.
  systemd.services.hermes-kb-init = {
    description = "Initialize Hermes knowledge base (pgvector + roles)";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      Group = "postgres";
    };
    script = ''
      set -euo pipefail
      PSQL=${pkgs.postgresql_17}/bin/psql
      $PSQL -d hermes_kb -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS vector;"
      $PSQL -d hermes_kb -v ON_ERROR_STOP=1 \
        -c "ALTER USER hermes_kb_ingest WITH PASSWORD '$(cat ${config.sops.secrets."hermes-kb-ingest-password".path})';"
      $PSQL -d hermes_kb -v ON_ERROR_STOP=1 \
        -c "ALTER USER hermes_kb_read WITH PASSWORD '$(cat ${config.sops.secrets."hermes-kb-read-password".path})';"
      $PSQL -d hermes_kb -v ON_ERROR_STOP=1 -c "GRANT ALL ON SCHEMA public TO hermes_kb_ingest;"
      $PSQL -d hermes_kb -v ON_ERROR_STOP=1 -c "GRANT USAGE ON SCHEMA public TO hermes_kb_read;"
      $PSQL -d hermes_kb -v ON_ERROR_STOP=1 -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO hermes_kb_read;"
      $PSQL -d hermes_kb -v ON_ERROR_STOP=1 \
        -c "ALTER DEFAULT PRIVILEGES FOR ROLE hermes_kb_ingest IN SCHEMA public GRANT SELECT ON TABLES TO hermes_kb_read;"
    '';
  };

  # KB role passwords — stored in the agent-editable sops file so the agent
  # can rotate them without root. sops-nix decrypts to /run/secrets at boot;
  # the oneshot (User=postgres) needs read access -> owner postgres.
  sops.secrets."hermes-kb-ingest-password" = {
    sopsFile = ../../secrets/secrets-extra.yaml;
    owner = "postgres";
    group = "postgres";
  };
  sops.secrets."hermes-kb-read-password" = {
    sopsFile = ../../secrets/secrets-extra.yaml;
    owner = "postgres";
    group = "postgres";
  };
}
