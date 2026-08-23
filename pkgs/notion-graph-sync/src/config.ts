/**
 * notion-graph-sync configuration.
 *
 * This is the ONLY file you should need to edit to change what gets synced.
 * Everything downstream (fetching, filtering, graph building, the privacy
 * gate) reads from here.
 *
 * PRIVACY MODEL (read this before adding entries):
 *   - The emitted graph-data.json contains ONLY: node ids, titles/labels,
 *     cluster names, tags, timestamps, and edge weights.
 *   - Page body text is fetched for TF-IDF similarity scoring but is held in
 *     memory only and NEVER written out.
 *   - URLs are never emitted. The harmlessness gate hard-fails the run if any
 *     "url" key, banned substring, or over-long string sneaks into the output
 *     (see BANNED_SUBSTRINGS / MAX_STRING_LENGTH below and src/gate.ts).
 */

// ---------------------------------------------------------------------------
// Clusters
// ---------------------------------------------------------------------------

/** Every cluster name used by the visualizer. Add a new one here first. */
export type Cluster =
  | "personal"
  | "science-tech"
  | "trading"
  | "learning"
  | "life"
  | "investing"
  | "archives"
  | "professional-work";

// ---------------------------------------------------------------------------
// INCLUDES — what gets pulled from Notion
// ---------------------------------------------------------------------------

export interface DataSourceInclude {
  /** Notion database id (dashes optional; API accepts both forms). */
  id: string;
  /** Human label, used only in logs. Row titles come from Notion itself. */
  label: string;
  /** Cluster assigned to every row pulled from this database. */
  cluster: Cluster;
}

export interface HubPageInclude {
  /** Notion page id of the hub. */
  id: string;
  /** Cluster assigned to this hub and its whole subtree. */
  cluster: Cluster;
  /**
   * How many levels of child_page blocks to drill BELOW the hub.
   *   0 = hub node only, no children at all
   *   1 = hub + its direct child pages
   *   N = N levels drilled; children one level deeper appear as leaf notes
   *       (their titles are free from the parent's block list, so we include
   *       them without an extra request).
   */
  depth: number;
}

export const INCLUDES = {
  /** Databases whose rows become `note` nodes (one node per included row). */
  dataSources: [
    { id: "11ee485f-e563-4f69-86b7-3ed7be9babd0", label: "Idea Dump", cluster: "personal" },
    { id: "3bfcd4d7-9bb4-4978-b42c-9cb1f0d2490e", label: "Quick Notes", cluster: "personal" },
    { id: "6a16c6ff-76d1-443d-845b-bf6b077ffee9", label: "Consumption Table", cluster: "personal" },
    { id: "11f3c52b-8afe-41f8-b5a0-c051bbb54cbc", label: "Interesting/Recommended Tools", cluster: "science-tech" },
    { id: "b1f72eab-24eb-41b3-b69b-1c0da66bcc74", label: "Reading List", cluster: "personal" },
    { id: "c0182ff2-7c3d-41e3-b74a-f38869a5f1bb", label: "Tweets", cluster: "personal" },
    { id: "728c7a1b-3cc6-4311-ada4-984c3bd53583", label: "Backend Topics", cluster: "science-tech" },
    { id: "24801cef-adef-415d-8d14-b5bfd2d04528", label: "VPS", cluster: "science-tech" },
    { id: "1494188b-6f6a-8177-9b29-000b441d8549", label: "Trading Strategies", cluster: "trading" },
    { id: "1494188b-6f6a-81d5-adab-000bad0020f8", label: "Trading Journal - Notes DB", cluster: "trading" },
    { id: "4d4e744f-e9c5-4310-bb56-6d4c53438ae4", label: "infographics", cluster: "personal" },
    { id: "a6be627f-edce-46dd-b1cf-cde49502a991", label: "Spaced Repetition", cluster: "learning" },
    { id: "8479f3fa-12a9-4210-8ae2-f927161ce28b", label: "Recipes", cluster: "life" },
  ] satisfies DataSourceInclude[],

  /** Hub pages whose subtrees are drilled recursively for hierarchy edges. */
  hubPages: [
    // Root hub: node only, deliberately NOT drilled (children would pull in
    // everything under Second Brain).
    { id: "12862de9-1495-4dc0-80a1-80a432f6aa35", cluster: "personal", depth: 0 },
    { id: "eded468e-b93e-49e7-9457-4e84fb6ebac3", cluster: "science-tech", depth: 3 },
    { id: "1494188b-6f6a-8026-9aae-e706d5cf3ea3", cluster: "investing", depth: 2 },
    { id: "29e3a9b5-52b6-49bf-b4a2-2182862cabf8", cluster: "archives", depth: 2 },
    { id: "152a2849-0db8-4a84-be23-cb7c69ac6667", cluster: "personal", depth: 3 },
  ] satisfies HubPageInclude[],
};

// ---------------------------------------------------------------------------
// WORK_INCLUDES — plain work pages, single umbrella cluster
// ---------------------------------------------------------------------------

/**
 * Work knowledge pages, all under one anonymized umbrella cluster.
 * Employer hub pages are deliberately NOT included — no employer name may
 * become a node in any form. The harmlessness gate additionally bans the
 * employer-name substrings below (GATE.bannedSubstrings), so even a future
 * page title containing one fails the run closed.
 */
export const WORK_INCLUDES = {
  cluster: "professional-work" as Cluster,

  pages: [
    "2684188b-6f6a-809a-ab21-c67d84f444aa",
    "1b34188b-6f6a-8057-8e71-e85c4f03be7c",
    "1b54188b-6f6a-80ca-bc09-c576837dbc0e",
    "2964188b-6f6a-8008-9d42-d91b5e465f98",
    "3ba4188b-6f6a-8042-8ea4-f27fcc6ddfda",
    "3aa4188b-6f6a-8020-9999-cc4886901685",
    "36a4188b-6f6a-801a-a9fa-e58490e846c7",
    "2254188b-6f6a-8070-8823-d8864f7a26b3",
    "2554188b-6f6a-80e3-a0e5-f9a0e828a67f",
    "2624188b-6f6a-803d-8a6c-e065f2bc639d",
    "2014188b-6f6a-8033-8fc5-f0bd77cda1dd",
    "1ec4188b-6f6a-804d-a889-e061fa1ab796",
    "3aa4188b-6f6a-80a6-87ea-ff464faa76c2",
    "27d4188b-6f6a-80a0-9bc3-e0955da78b74",
    "2a84188b-6f6a-80ac-80c1-f58a2384bfbf",
    "2414188b-6f6a-80bf-99ad-d9561c83b708",
  ] satisfies string[],
} as const;

// ---------------------------------------------------------------------------
// EXCLUDES — applied EVERYWHERE (db rows, tree nodes, work pages)
// ---------------------------------------------------------------------------

export const EXCLUDES = {
  /**
   * Case-insensitive name patterns. A page/db-row whose title matches ANY of
   * these is dropped — UNLESS its id appears in an explicit include list above
   * (explicit-include beats pattern-exclude; see src/filters.ts).
   */
  namePatterns: [
    /^tracked$/i,
    /^assignments?$/i,
    /^grade/i,
    /^topic$/i,
    /^(jago|budget|net worth)/i,
    /^(routine|goals-progress|yearly hours)/i,
    /^(modul|tes akhir|jurnal|schedule|master schedule|classes)$/i,
    /^(to buy|watching list|list|travel plans|service motor|me|gifts)/i,
    /meet/i,
    /catch-up/i,
    /orientation/i,
    // NOTE: the Archives HUB page id is explicitly included above, so this
    // pattern drops other "Archive(s)" pages but never the hub itself.
    /^archives?$/i,
    /^untitled$/i,
    // Client codename — explicitly banned from public output.
    /osmt/i,
    // Employer name — same treatment: drop any page whose TITLE mentions it
    // entirely rather than gating. (Explicitly included ids still beat this
    // pattern; the gate's banned substring remains the backstop for those.)
    /nine dots/i,
  ] satisfies RegExp[],
};

// ---------------------------------------------------------------------------
// Harmlessness gate
// ---------------------------------------------------------------------------

export const GATE = {
  /**
   * Substrings that must NEVER appear anywhere in the emitted JSON
   * (checked case-insensitively). Includes Notion's own domains — a leaked
   * page URL would otherwise slip through as a "title". Add client
   * codenames / domains here.
   */
  bannedSubstrings: [
    "osmt",
    // Employer names — banned outright per the no-employer-names decision.
    "nine dots",
    "ddb",
    "dev.azure.com",
    "notion.com",
    "app.notion.so",
    "notion.so",
  ] as string[],

  /**
   * Any single string longer than this fails the gate. Titles and tags are
   * short; this catches leaked body fragments or pasted URLs.
   */
  maxStringLength: 120,

  /**
   * Emitted labels longer than this are truncated (with a "…" suffix) at
   * graph-assembly time — long article/tweet titles are legitimate content,
   * not leaks. The gate's maxStringLength check on labels becomes a pure
   * backstop that should never fire. Keep <= maxStringLength.
   */
  maxLabelLength: 120,
};

// ---------------------------------------------------------------------------
// Edge thresholds
// ---------------------------------------------------------------------------

export const THRESHOLDS = {
  /** Minimum tag-set Jaccard similarity to emit a `tag` edge. */
  tagJaccardMin: 0.34,

  /** Minimum TF-IDF cosine score to consider a `similarity` edge. */
  similarityMin: 0.25,

  /** Per-node top-K similar neighbors before symmetrization. */
  similarityTopK: 5,
};

// ---------------------------------------------------------------------------
// Runtime knobs
// ---------------------------------------------------------------------------

export const RUNTIME = {
  /** API root; override with NOTION_API_BASE for testing against a stub. */
  apiBase: process.env.NOTION_API_BASE ?? "https://api.notion.com/v1",
  /** Min milliseconds between Notion API requests (~3 req/sec limit). */
  rateLimitMs: 350,

  /** Max retries on HTTP 429, honoring Retry-After each time. */
  maxRetries: 5,

  /**
   * Notion API version header, sent on EVERY request.
   * Pinned to 2025-09-03 or newer: from this version on, the ids in
   * INCLUDES.dataSources are DATA-SOURCE ids and must be queried at
   * POST /v1/data_sources/{id}/query — the legacy /v1/databases/{id}/query
   * endpoint 404s for them.
   */
  notionVersion: "2025-09-03",

  /**
   * Max first-level blocks read per database-row page when fetching body text
   * for TF-IDF (see NotionClient.fetchRowText). First-level blocks give enough
   * similarity signal; the cap bounds work on pathological mega-pages.
   */
  rowTextMaxBlocks: 50,
};

/**
 * Optional mapping of hub page id -> data source ids, emitting extra
 * hierarchy edges (hub -> each row of that database) at weight 1.0.
 *
 * Empty by default because the hub<->database ownership isn't declared
 * anywhere in Notion metadata; fill it in if you want those edges, e.g.:
 *   "12862de9-1495-4dc0-80a1-80a432f6aa35": ["b1f72eab-24eb-41b3-b69b-1c0da66bcc74"]
 */
export const HUB_TO_DATA_SOURCES: Record<string, string[]> = {};
