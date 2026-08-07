{
  imports = [
    # ./llmsherpa.nix
    ./blogablog.nix
    ./fno-interactor.nix
    ./nine-dots-hours-dashboard.nix
    ./keep2notion.nix
    ./tasks2notion.nix
    # Minecraft stack disabled 2026-08-08 — not in use (server, backend,
    # discord bot, web dashboard). Re-enable by uncommenting:
    # ./mc.nix
    # ./mc-management.nix
  ];
}
