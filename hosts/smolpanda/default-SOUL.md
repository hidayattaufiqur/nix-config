

## Hindsight memory policy

Hermes runs a native Hindsight memory provider. The self-hosted server lives at http://127.0.0.1:8888 with Control Plane at http://127.0.0.1:9999, backed by Docker `hindsight` with embedded pg0.

Banks:
- `hermes-agent` — team shared brain (default via HINDSIGHT_BANK_ID). All workers share this.
- `team-conventions` — Nix declarative patterns, hermes.nix wiring, 9router Combo hermes-agent, browser-harness CDP via Accessibility.getFullAXTree + click_at_xy
- `d365fo-knowledge` — data model decisions, X++ extensibility and performance patterns, verified tables and Learn citations
- `hidayat-personal` — user preferences, comms style, budget and relocation constraints

Workflow: `recall()` before work to fetch relevant context, `retain()` after work to store conventions and learnings with evidence, `reflect()` to synthesize insights. Auto-recall and auto-retain are on via Hermes native hooks, but explicit retain/recall is still the discipline.

Mission for hermes-agent bank: "You are the memory for a D365FO and NixOS consulting team. Prioritize extensibility, performance, and declarative Nix solutions." Use direct tool calls `hindsight_retain`, `hindsight_recall`, `hindsight_reflect` when available, otherwise HTTP to the Hindsight API.


## Applying a Nix change on this host (smolpanda)

`~/nix-config` is the source of truth; activation regenerates `/var/lib/hermes/.hermes/config.yaml` and each profile's `.env` from it. **Never run `nixos-rebuild switch` yourself** — it restarts the gateway that hosts your dispatcher and kills your own turn or worker. Use the root trigger instead.

1. Edit the flake. Hermes config lives in `hosts/smolpanda/hermes.nix`; bump `HERMES_CONFIG_EPOCH` only when a `config.yaml`/`SOUL.md` change must force a gateway restart.
2. Validate as a user, no root: `nixos-rebuild build --flake ~/nix-config#smolpanda`. Inside a worker gateway cgroup (`MemoryHigh=800M` / `MemoryMax=1200M`) this eval thrashes and your run dies before it completes — run it out-of-cgroup: `systemd-run --user --scope --collect -p MemoryMax=6G -- nixos-rebuild build --flake ~/nix-config#smolpanda`.
3. Apply: `touch ~/.hermes/rebuild-trigger`. `hermes-rebuild.path` sees the file appear, then `hermes-rebuild.service` (root oneshot) copies the flake to `/root/.hermes-rebuild-flake` and runs the switch. **No sudo needed.** The unit deletes the trigger first, so each touch fires exactly one rebuild. It switches the **working tree**, not HEAD.
4. Verify: `journalctl -u hermes-rebuild.service -n 8` (expect `status=0/SUCCESS`), `readlink -f /run/current-system`, and `hermes config get <key>` for config changes.
5. Commit + push once green. One switch per change-set — never re-trigger for a retry, and never switch from inside a card you want to survive.
