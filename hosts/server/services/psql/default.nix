{
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "postgres" ];
    enableTCPIP = true;
    settings.port = 5432;
  };
}
