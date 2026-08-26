# smolpanda public HTTP(S) surface.
#
# Import this from ./default.nix only AFTER DNS for the domains has been
# switched to this host. Enabling it earlier would deadlock ACME: nginx
# references certs that cannot be issued until port 80/443 reach this host.

{
  imports = [
    ../../services/apps/nginx
  # uptime-kuma nginx proxy removed 2026-08-26 (OOM declutter) — the backend
  # service was disabled (workloads.nix import dropped).
    # grafana disabled 2026-08-08 — unused (module kept in services/grafana.nix)
  ];
}
