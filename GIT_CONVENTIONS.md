# Git Conventions

Guidelines for commits, branching, and GitHub operations in this repo.
These rules apply to humans and agents alike.

---

## Commit Message Format

```
type(scope): short imperative description
```

- **type** and **scope** are lowercase
- **description** is lowercase, imperative mood ("add" not "added", "fix" not "fixes")
- Keep the subject line under 72 characters
- No trailing period

### Types

| Type | When to use |
|------|-------------|
| `feat` | Adding a new service, module, or configuration block |
| `fix` | Correcting a broken config, service failure, or misbehaviour |
| `chore` | Maintenance: GC settings, log rotation, cleanup, dependency bumps |
| `refactor` | Restructuring existing config without changing behaviour |
| `docs` | Changes to `.md` files only |
| `revert` | Reverting a previous commit |

### Scopes

Use the host or component being changed:

| Scope | Covers |
|-------|--------|
| `server` | `hosts/server/` — general server config |
| `nginx` | `hosts/server/services/nginx/` |
| `flake` | `flake.nix`, `flake.lock` |
| `secrets` | `.sops.yaml`, `secrets/` |
| `services` | `services/` — shared service modules |
| `desktop` | `hosts/desktop/` |
| `laptop` | `hosts/laptop/` |
| `nvim` | Neovim configuration |
| `zsh` | ZSH / shell configuration |
| `packages` | System package lists |

Omit scope only when the change is truly repo-wide (rare).

### Examples

```
feat(server): add uptime-kuma service with sops env injection
fix(nginx): add forceSSL and enableACME to all vhosts
chore(server): cap journal to 300M, set prometheus retention to 7d
refactor(services): split prometheus scrape config into separate file
docs: update PLANS.md with completed SOPS steps
chore(flake): bump nixpkgs-unstable input
secrets: re-encrypt secrets.yaml for server host key
```

---

## Branching

- All work goes directly to **`main`** unless it is experimental or risky.
- For risky changes (kernel params, disk layout, new secrets backend), use a
  short-lived branch named `type/short-description`, e.g. `feat/ollama-service`.
- Delete branches after merge; this repo has no long-lived feature branches.

---

## Push Rules

- **Always push after a successful `nixos-rebuild switch`** — the remote should
  always reflect what is actually running on the server.
- **Never force-push `main`** without explicit owner approval.
- **Never amend a commit that has already been pushed** to the remote.
- Agents must not push if the rebuild failed or was not attempted.

---

## Rebuild Before Push

The sequence for any config change is:

```
1. Edit files in /home/nixos-server/nix-config
2. sudo nixos-rebuild switch --flake /home/nixos-server/nix-config#nixos-server
3. Verify the affected service is running (systemctl status <service>)
4. git add + git commit + git push
```

Never commit a config that has not been tested with `nixos-rebuild switch`.

---

## Agent-Specific Rules

- Do not commit files containing secrets in plaintext (`.env`, credential JSONs,
  unencrypted keys). All secrets must go through SOPS — see `PLANS.md`.
- Do not commit `result/` symlinks (already in `.gitignore`).
- When summarising work across sessions, record the latest commit SHA so the
  next session knows exactly where the repo stands.
