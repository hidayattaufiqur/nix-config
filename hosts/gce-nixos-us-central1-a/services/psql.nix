{ ... }:
{
  # imports = [ inputs.sops-nix.nixosModules.sops ];

  # sops.defaultSopsFile = ./../../../secrets/secrets.yaml;
  # sops.defaultSopsFormat = "yaml";

  # sops.age.keyFile = "/home/nixos-box/.config/sops/age/keys.txt";

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "postgres" "tugas_akhir" ];
    enableTCPIP = true;
    port = 5432;
  };

  # sops.secrets."postgres/ta_server/postgres_password" = {
  #   owner =  "postgres";
  #   restartUnits = [ "postgresql.service" ];
  # };
  #
  # sops.secrets."postgres/ta_server/postgres_role" = {
  #   owner =  "postgres";
  #   restartUnits = [ "postgresql.service" ];
  # };
  #
  # systemd.services.postgresql.postStart =
  #   let
  #     db_name = config.sops.secrets."postgres/ta_server/postgres_db".path;
  #     password_file_path = config.sops.secrets."postgres/ta_server/postgres_password".path;
  #   in
  #   ''
  #     $PSQL -tA <<'EOF'
  #       DO $$
  #       DECLARE password TEXT;
  #       BEGIN
  #         password := trim(both from replace(pg_read_file('${password_file_path}'), E'\n', '''));
  #         EXECUTE format('ALTER ROLE ${db_name} WITH PASSWORD '''%s''';', password);
  #       END $$;
  #     EOF
  #   '';
}
