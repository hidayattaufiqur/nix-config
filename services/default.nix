{
  imports = [
    ./server-role.nix
    ./ssh.nix
    ./psql.nix
    ./nginx.nix
    # ./cockpit.nix
    ./systemd.nix
    ./redis.nix
    ./tailscale.nix
  ];
}
