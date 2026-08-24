{
  # Install the Hermes backup script into the Hermes scripts dir so the
  # hermes-backup.service ExecStart path is always current (declarative copy).
  system.activationScripts.hermes-backup-script = {
    text = ''
      install -m 0755 -o smolpanda -g users ${./hermes-backup.sh} /var/lib/hermes/.hermes/scripts/hermes-backup.sh
    '';
    deps = [ ];
  };

  imports = [
    # ./llmsherpa.nix
    ./blogablog.nix
    ./fno-interactor.nix
    ./nine-dots-hours-dashboard.nix
    ./keep2notion.nix
    ./tasks2notion.nix
    ./notion-graph-sync.nix
    ./hermes-backup.nix
    ./nix-clean.nix
    # Minecraft stack disabled 2026-08-08 — not in use (server, backend,
    # discord bot, web dashboard). Re-enable by uncommenting:
    # ./mc.nix
    # ./mc-management.nix
  ];
}
