# smolpanda server workloads — mirror of the old nixos-server apps.
#
# Backend application services only. Public HTTP(S) surface (nginx vhosts,
# ACME, Grafana, uptime-kuma proxy) lives in ./public.nix and is enabled only
# after DNS has been switched to this host.

{ config, lib, pkgs, sops-install-secrets, ... }:
{
  imports = [
    ../../services/server-role.nix
    ../../services/psql.nix
    ../../services/nginx.nix
    ../../services/systemd.nix
    ../../services/redis.nix
    ../../services/prometheus_node_exporter.nix
    ../../services/prometheus.nix
    ../../services/apps/systemd
    ../../services/apps/redis
    ../../services/apps/psql
    ../../services/apps/mc
    ../../services/apps/mc-management
    ../../services/uptime-kuma/default.nix
  ];

  # Run all server workloads under the smolpanda account.
  services.server-role = {
    user = "smolpanda";
    homeDir = "/home/smolpanda";
  };

  # Docker is needed by the websnag compose stack.
  virtualisation.docker.enable = true;
  users.users.smolpanda.extraGroups = [ "docker" ];

  # SOPS secrets (uptime-kuma dbPassword). Requires sops wiring in flake.nix
  # (sops-nix module + sops-install-secrets in specialArgs).
  sops.package = sops-install-secrets;
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Public surface: SSH, HTTP(S), Minecraft. Tighten once Tailscale is in.
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedTCPPorts = [ 22 80 443 25565 25575 ];
    allowedUDPPorts = [ 19132 25565 25575 ];
    checkReversePath = "loose";
  };
}
