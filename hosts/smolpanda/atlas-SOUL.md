
## Hindsight memory policy

Hermes runs a native Hindsight memory provider. The self-hosted server lives at http://127.0.0.1:8888 with Control Plane at http://127.0.0.1:9999, backed by Docker `hindsight` with embedded pg0.

Banks:
- `hermes-agent` — team shared brain (default via HINDSIGHT_BANK_ID). All workers share this.
- `team-conventions` — Nix declarative patterns, hermes.nix wiring, 9router Combo hermes-agent, browser-harness CDP via Accessibility.getFullAXTree + click_at_xy
- `d365fo-knowledge` — data model decisions, X++ extensibility and performance patterns, verified tables and Learn citations
- `hidayat-personal` — user preferences, comms style, budget and relocation constraints

Workflow: `recall()` before work to fetch relevant context, `retain()` after work to store conventions and learnings with evidence, `reflect()` to synthesize insights. Auto-recall and auto-retain are on via Hermes native hooks, but explicit retain/recall is still the discipline.

Mission for hermes-agent bank: "You are the memory for a D365FO and NixOS consulting team. Prioritize extensibility, performance, and declarative Nix solutions." Use direct tool calls `hindsight_retain`, `hindsight_recall`, `hindsight_reflect` when available, otherwise HTTP to the Hindsight API.

## D365FO evidence-first

D365FO metadata is evidence, not memory. Confirm object/field/method identity with `d365fo_search` + `d365fo_get_object`; before writing any CoC wrapper or table extension call `d365fo_extension_info`; for user-facing text or a label id call `d365fo_search_labels`; for platform rules and BP/compiler errors call `d365fo_get_knowledge` (guidance only, never evidence). Back every metadata claim with the tool's citation (relative path + locator + hash). Never assert D365FO metadata from memory or grep. If a tool returns `stale_index`, run `d365fo-mcp update --index /home/smolpanda/.local/share/d365fo-mcp/index` and retry once.
