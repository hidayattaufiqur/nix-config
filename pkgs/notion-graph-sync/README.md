# notion-graph-sync

Pulls a curated subset of a personal Notion workspace via the Notion API and
emits a static `graph-data.json` for a public knowledge-graph visualization.

**Privacy-critical:** the emitted artifact contains ONLY titles + metadata —
never page body text, never URLs. A harmlessness gate hard-fails the run
(writing nothing) if any `url` key, banned substring in a human-meaningful
field (`label`, `cluster`, `tags[]` — opaque ids/sources/targets are exempt,
since Notion UUIDs are random hex), over-long string, or off-schema key
reaches the output. Labels longer than `GATE.maxLabelLength` (default 120)
are truncated with an ellipsis at assembly time, so long article/tweet
titles survive without tripping the gate.

## Requirements

- Node.js >= 23.6 (runs TypeScript directly via native type stripping — no
  build step, no runtime dependencies).
- Dev-only: `typescript` for `npm run typecheck`.

## Usage

```bash
# from this directory
npm install            # dev tooling only (typescript / @types/node)

export NOTION_TOKEN=secret_...   # Notion internal integration token

# real run — writes ./graph-data.json
node src/main.ts

# explicit output path
node src/main.ts --output /srv/graph/graph-data.json

# fetch + compute + print summary, write NOTHING
node src/main.ts --dry-run

# tests / typecheck
npm test
npm run typecheck
```

Without `NOTION_TOKEN` the CLI exits 1 with instructions.

## Output contract

```json
{
  "meta": { "generatedAt": "<iso>", "version": 1 },
  "nodes": [
    { "id": "...", "label": "...", "kind": "hub|note", "cluster": "...",
      "tags": ["..."], "createdAt": "...", "updatedAt": "..." }
  ],
  "edges": [
    { "source": "...", "target": "...", "type": "hierarchy|tag|similarity", "weight": 0.0 }
  ]
}
```

Nodes are sorted by id, edges by source+target(+type) — re-runs are
byte-stable apart from `generatedAt`, so the file diffs cleanly in git.

Edge types:

- `hierarchy` (weight 1.0): parent→child from drilled hub subtrees, plus
  optional hub→database-row edges via `HUB_TO_DATA_SOURCES`.
- `tag`: shared multi_select tags, weight = Jaccard similarity, kept ≥ 0.34.
- `similarity`: TF-IDF cosine over in-memory page text, kept ≥ 0.25,
  top-5 neighbors per node, symmetrized. Body text is fetched for ALL nodes:
  hub-subtree/work pages recursively, database rows via first-level blocks
  only (capped at `RUNTIME.rowTextMaxBlocks` = 50 blocks per row).

## Configuring what gets synced

Everything lives in [`src/config.ts`](src/config.ts) and is heavily commented:

- `INCLUDES.dataSources` — databases whose rows become `note` nodes
  (id → cluster mapping).
- `INCLUDES.hubPages` — hub pages drilled recursively (`depth: 0` = hub node
  only; `N` = N levels of children). Intermediate container pages become
  `hub` nodes, leaves become `note`s.
- `WORK_INCLUDES` — plain work pages, all under the single anonymized
  `professional-work` cluster. Employer hub pages are deliberately NOT
  included (no employer name may become a node); the gate additionally bans
  the employer-name substrings, so a future title containing one fails the
  run closed rather than leaking.
- `EXCLUDES.namePatterns` — case-insensitive title filters applied everywhere.
  Explicitly included ids always beat pattern excludes (that's how the
  "Archives" hub survives `/^archives?$/i`).
- `GATE.bannedSubstrings` — strings that must never appear in output
  (add client codenames and employer names here).
- `THRESHOLDS`, `RUNTIME` — edge thresholds and rate limiting (~3 req/s).

## Notes

- Page body text is fetched only to compute TF-IDF vectors and is held in
  memory; it is never serialized.
- Database rows get first-level block text (non-recursive, capped at
  `RUNTIME.rowTextMaxBlocks`) so their similarity vectors aren't empty — this
  is what keeps similarity edges alive. Costs roughly one extra request per
  row: at ~530 rows and the 350 ms throttle that's about +3–4 minutes of
  runtime on a full sync. Raise the cap or recurse into `has_children`
  blocks in `NotionClient.fetchRowText` if row-level similarity ever comes
  up thin.
- Rate limiting: min 350 ms between requests, honors `Retry-After` on 429.
  A full sync of the current include list takes roughly 5–8 minutes with
  row-text fetching enabled.
