nix-config — personal NixOS configurations (flake-based)

## Motivation

The motivation behind NixOS is removing the hassle of re-configuring work and personal environments across every machine I have — and the peace of mind that comes from knowing the same config can reproduce a machine from scratch if things go wrong. Configurations that used to live in scattered dotfiles and half-remembered SSH sessions now live in version control, declarative, and version-locked.

I'm also interested and fascinated by the world of Nix and NixOS in general, and I'm still learning about them.

## What this repo manages

- `flake.nix` / `flake.lock` — flake inputs and pinned revisions
- `hosts/` — per-host NixOS configurations (`nixos`, `nixos-box`, `nixos-server`, and a dormant GCE instance)
- `home-manager/` — reusable user-level configuration (shell, editor, dotfiles)
- `services/` — service definitions (nginx vhosts, systemd units, cloudflared)
- `secrets/` — encrypted secrets managed via `sops-nix`
- `PLANS.md` — current plans and historical notes

## Practical wins (in this repo)

- **nginx + ACME**: TLS and vhosts are declared in Nix. No certbot, no cron, no standalone flag. Certificates Just Work.
- **Custom systemd services**: apps like `fno-interactor` and `mc-management` are defined as systemd units in the repo — reproducible without SSHing in.
- **Monitoring**: Prometheus + Grafana + node exporter, all in the same flake, deployed with the rest of the config.
- **Declarative disk layout**: the VPS uses `disko` so the disk setup is code and can be reprovisioned over SSH with `nixos-anywhere`.
- **Secrets**: `sops-nix` is wired up and actively managing secrets.
- **Operations**: journald capped, Prometheus retention configured, nix GC tuned — all declarative, all versioned.

## Blog posts

Writing about this stuff on my blog:
- "One Flake to Rule Them All" — https://hidayattaufiqur.dev/blog
- "Install NixOS on Google Compute Engine" — https://hidayattaufiqur.dev/blog

## Common commands

```bash
# Rebuild and switch a host
sudo nixos-rebuild switch --flake .#nixos        # laptop
sudo nixos-rebuild switch --flake .#nixos-box    # desktop
sudo nixos-rebuild switch --flake .#nixos-server # VPS

# Apply home-manager changes
home-manager switch --flake .#nixos
```

## Caveats and known issues

- Nix has a real learning curve — the docs are good but the mental model is different from traditional distros.
- GNOME extensions are sensitive to channel mixing: keep extension packages on the same channel as your GNOME shell version.
- Some precompiled binaries assume an FHS layout — `nix-ld` is used as an escape hatch.
- See `PLANS.md` for notes on key rotation and other operational details.

## TODO

- [ ] Declaratively create PostgreSQL users and databases
- [x] SOPS integration (active)
- [x] Cloudflared service (enabled via SOPS)
- [x] Split configs so they work across local machines and servers

## License

Personal config. Use as a reference, adapt for your own environment, and always review input bumps carefully before applying them everywhere.
