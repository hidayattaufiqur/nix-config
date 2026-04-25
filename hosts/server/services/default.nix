{
  imports = [
    ./nginx
    ./systemd
    ./redis
    ./psql
    ./firewall
    ./mc
    ./mc-management
    ../../../services/uptime-kuma/default.nix
    ../../../services/uptime-kuma/nginx.nix
  ];
}
