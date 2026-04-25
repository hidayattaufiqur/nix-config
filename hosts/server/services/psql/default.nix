{
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "postgres" "uptime_kuma" ];
    ensureUsers = [
      { name = "uptime_kuma"; }
    ];
    enableTCPIP = true;
    settings.port = 5432;
  };
}
