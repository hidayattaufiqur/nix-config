{
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "postgres" "uptime_kuma" "websnag" ];
    ensureUsers = [
      { name = "uptime_kuma"; }
      {
        name = "websnag";
        ensureDBOwnership = true;
      }
    ];
    enableTCPIP = true;
    settings.port = 5432;
    authentication = ''
      # Allow websnag Docker container (Docker bridge subnet)
      host  websnag  websnag  172.16.0.0/12  scram-sha-256
    '';
  };
}
