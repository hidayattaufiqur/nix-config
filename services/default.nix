{
  imports = [
    ./ssh.nix
    ./psql.nix
    ./nginx.nix
    # ./cockpit.nix
    ./systemd.nix
    ./redis.nix
    ./tailscale.nix
    # cloudflared.nix is intentionally excluded until SOPS is set up
    # (credentials file managed as a secret — see README for SOPS plan)
  ];
}
