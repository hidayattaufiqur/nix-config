# Root-gated server cleanup: prune Nix generations, GC, optimise, journal
# vacuum. The agent writes /home/smolpanda/.hermes/nix-clean-trigger; this
# .path unit sees the file appear and the oneshot runs the cleanup as root —
# the agent never needs sudo (its unit runs NoNewPrivileges). The service
# deletes the trigger first so each write fires exactly one cleanup.
{ pkgs, ... }:
{
  systemd.services.nix-clean = {
    description = "Server cleanup: prune Nix generations, GC, optimise, journal vacuum";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      WorkingDirectory = "/root";
      Environment = "PATH=${pkgs.nix}/bin:${pkgs.systemd}/bin:${pkgs.coreutils}/bin:/run/current-system/sw/bin";
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f /home/smolpanda/.hermes/nix-clean-trigger";
      ExecStart = [
        # Keep the 3 most recent generations (current + 2 rollback).
        "${pkgs.nix}/bin/nix-env --delete-generations +3 -p /nix/var/nix/profiles/system"
        "${pkgs.nix}/bin/nix-store --optimise"
        "${pkgs.nix}/bin/nix-collect-garbage -d"
        "${pkgs.systemd}/bin/journalctl --vacuum-size=100M"
      ];
    };
  };

  systemd.paths.nix-clean = {
    description = "Watch for the Hermes nix-clean trigger file";
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathExists = "/home/smolpanda/.hermes/nix-clean-trigger";
  };
}
