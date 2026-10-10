

## Hindsight memory policy

Hermes runs a native Hindsight memory provider. The self-hosted server lives at http://127.0.0.1:8888 with Control Plane at http://127.0.0.1:9999, backed by Docker `hindsight` with embedded pg0.

Banks:
- `hermes-agent` — team shared brain (default via HINDSIGHT_BANK_ID). All workers share this.
- `team-conventions` — Nix declarative patterns, hermes.nix wiring, 9router Combo hermes-agent, browser-harness CDP via Accessibility.getFullAXTree + click_at_xy
- `d365fo-knowledge` — data model decisions, X++ extensibility and performance patterns, verified tables and Learn citations
- `hidayat-personal` — user preferences, comms style, budget and relocation constraints

Workflow: `recall()` before work to fetch relevant context, `retain()` after work to store conventions and learnings with evidence, `reflect()` to synthesize insights. Auto-recall and auto-retain are on via Hermes native hooks, but explicit retain/recall is still the discipline.

Mission for hermes-agent bank: "You are the memory for a D365FO and NixOS consulting team. Prioritize extensibility, performance, and declarative Nix solutions." Use direct tool calls `hindsight_retain`, `hindsight_recall`, `hindsight_reflect` when available, otherwise HTTP to the Hindsight API.

## jev (mcp__jev__jev_evaluate) — when to call
jev is a classifier, not a source: it returns labels or 0..1 scores, never facts (`verified=false`).
Call `mcp__jev__jev_evaluate` at decision points where several NAMED options exist, to pick one.
Use the exact tool name: it is a deferred tool, so run `tool_describe` on it first if a direct call is not accepted.
- Which Notion database/route fits this request -> `choice` over the named options.
- Which tool/MCP fits this request (Notion MCP vs another) -> `choice` over the candidate tools.
- Does this text read as AI-made -> `boolean`/`score`, and paste the `humanizer` skill's rules verbatim as `criteria` (if that skill is not available in this profile, skip this one in v1).
Every call needs `criteria`: a map of option -> concrete description. If the options are not enumerable, DO NOT call jev — decide yourself.
Fail OPEN: low confidence (< 0.75), a tie, or a jev error means take the deterministic default (the option you would have picked anyway). Never use a jev score as evidence about Notion content.
