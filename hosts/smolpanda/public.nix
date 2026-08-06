# smolpanda public HTTP(S) surface.
#
# Import this from ./default.nix only AFTER DNS for the domains has been
# switched to this host. Enabling it earlier would deadlock ACME: nginx
# references certs that cannot be issued until port 80/443 reach this host.

{
  imports = [
    ../../services/apps/nginx
    ../../services/uptime-kuma/nginx.nix
    ../../services/grafana.nix
  ];
}
