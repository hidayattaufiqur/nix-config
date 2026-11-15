# Hermes 0.20.1 → 0.23.1 upgrade: DEFERRED (blocked on Hindsight/Nix)

Status as of 2026-11-15: **not upgrading.** Staying on vendored 0.20.1.

## Why

Upstream v0.23.1 moved every memory provider **out of core** into the plugin
catalog. `hindsight` is no longer a pip extra — `pyproject.toml` has zero
mentions of it — so `extraDependencyGroups = [ ... "hindsight" ]` fails the
build with:

```
error: Extra/group name 'hindsight' does not match either extra or dependency group
```

Hindsight now installs via `hermes plugins install hindsight` (catalog entry
v1.2.4, pinned sha f14cc1eb…), which pip-installs its two deps into the Hermes
venv:

```
hindsight-client>=0.10.1,<2
hindsight-embed>=0.10.1,<2
```

That is impossible here. Our venv is a sealed uv2nix derivation:

```nix
venv = pythonSet.mkVirtualEnv "hermes-agent-env" { hermes-agent = dependency-groups; };
```

`/nix/store` is read-only, so `hermes plugins install` cannot write into it.
Blocked upstream by **NousResearch/hermes-agent#140765** (open): "Nix installs:
every plugin enable/disable crashes in pm admission — uv.lock". Also relevant:
#43810 (`extraPythonPackages` breaks when a dep is already in the sealed set).

User decision: **keep Hindsight, defer the upgrade until upstream fixes Nix
plugin dependency installation.** Long-term memory carries the team's
conventions and D365FO knowledge, so it outranks a version bump.

## What was verified during the attempt (still valid, reuse later)

Tested against the built v0.23.1 store path, in isolation:

- **Vision** — upstream fix `a714ff9823b9` present (`_aux_probe_active` ×5,
  guard ×1). Better than our local patch: it also covers adapter-wrapped stubs.
  Our `vendor/hermes-aux-probe-stub.patch` (backport of the same fix) is
  redundant on any version ≥ that commit.
- **Kanban** — guard moved to `hermes_cli/kanban_db_dispatch.py`. Escapes
  `active_pr` only on `assigned` (profile change) / `changes_requested` /
  `review_reopened`. **A plain `kanban_unblock` does NOT lift `active_pr`**,
  unlike our `hermes-pr-guard.patch` which escaped on
  `('status','promoted','unblocked','reclaimed')`. Our patch is still needed on
  0.20.1 and would be a *behaviour regression* to drop without accepting that
  semantic change.
- **tool_search sanitizer** — still NOT upstream. `sanitize_api_messages` has
  zero `tool_search` handling. Patch stays required for long CommandCode
  `muse-spark` threads.
- **Gateway** — `load_config()` on v0.23.1 read our live 0.20.1 `config.yaml`
  without complaint. Python moves 3.12 → 3.14; all five critical modules
  import clean.

## To resume when #140765 closes

1. Point `hermes-agent.url` at `github:NousResearch/hermes-agent/v<new>`
2. Re-check whether `hindsight` is installable, or whether the Nix module grew
   a declarative plugin/extra-python path
3. Decide on the kanban `unblock`→`active_pr` behaviour change (accept upstream
   semantics, or re-port our re-queue escape)
4. Keep `vendor/hermes-tool-search-sanitizer.patch` unless it lands upstream
5. Rebuild, switch, then verify all four banks resolve:
   `hermes-agent`, `team-conventions`, `d365fo-knowledge`, `hidayat-personal`

## Hindsight config shape (for the eventual migration)

Plugin reads `$HERMES_HOME/hindsight/config.json` (or `~/.hindsight/config.json`),
NOT `config.yaml`'s `memory.hindsight` block. Keys map 1:1:

| config.yaml (now) | plugin config.json |
|---|---|
| `mode: cloud` | `mode` (`cloud` / `local_embedded` / `local_external`) |
| `api_url: http://127.0.0.1:8888` | `api_url` |
| `bank_id: hermes-agent` | `bank_id` (or `bank_id_template`) |
| `recall_budget: mid` | `recall_budget` (legacy alias `budget`) |

Banks themselves live in the Hindsight server, not in Hermes — they do not move.
Use `local_external` to keep talking to the existing 127.0.0.1:8888 server;
`local_embedded` would spawn a separate daemon (not wanted).

Note: `hermes plugins enable` does NOT activate a memory provider — providers
are `kind: exclusive` and activation is `memory.provider: <name>`.
