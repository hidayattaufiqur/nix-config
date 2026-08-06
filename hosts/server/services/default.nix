{
  imports = [
    ./firewall
    ../../../services/apps/nginx
    ../../../services/apps/systemd
    ../../../services/apps/redis
    ../../../services/apps/psql
    ../../../services/apps/mc
    ../../../services/apps/mc-management
    ../../../services/uptime-kuma/default.nix
    ../../../services/uptime-kuma/nginx.nix
  ];
}
