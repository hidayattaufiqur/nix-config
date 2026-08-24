# Nightly Hermes state backup (storage-conscious).
# Runs hermes-backup.sh as the smolpanda user: consistent sqlite snapshots of
# live WAL DBs, tar.gz of state/config/skills/memories/cron, 7-snapshot
# retention, archives 700/600 (auth.json contains credential pool entries).
# The script is installed into /var/lib/hermes/.hermes/scripts/ by the
# services/apps/systemd/default.nix module; that copy is authoritative.
{ pkgs, ... }:
{
  systemd.services.hermes-backup = {
    description = "Nightly Hermes state backup";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "smolpanda";
      Group = "users";
      Environment = "PATH=${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin:${pkgs.sqlite}/bin:/run/current-system/sw/bin";
      ExecStart = "/var/lib/hermes/.hermes/scripts/hermes-backup.sh";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.timers.hermes-backup = {
    description = "Run Hermes state backup nightly at 03:17";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:17:00";
      Persistent = true;
      Unit = "hermes-backup.service";
    };
  };
}
