/**
 * notion-graph-sync CLI entry point.
 *
 * Usage:
 *   NOTION_TOKEN=secret notion-graph-sync [--output <path>] [--dry-run] [--no-preflight]
 *
 * Normal mode writes the privacy-gated graph JSON to --output.
 * A preflight check (skippable via --no-preflight) verifies the integration
 * can see every configured entry before any other request is made.
 * --dry-run fetches and computes everything, prints a summary report
 * (nodes per cluster/kind, edges per type, gate result) but writes nothing.
 */

import {
  EXCLUDES,
  INCLUDES,
  HUB_TO_DATA_SOURCES,
  THRESHOLDS,
  WORK_INCLUDES,
} from "./config.ts";
import { shouldIncludeNode } from "./filters.ts";
import { NotionClient } from "./notion.ts";
import type { DbRow, TreeNode } from "./notion.ts";
import { runGate } from "./gate.ts";
import type { GateViolation } from "./gate.ts";
import { collectExpectedEntries, diffPreflight, printPreflight, PREFLIGHT_GUIDANCE } from "./preflight.ts";
import { assembleGraph, tagEdges } from "./graph.ts";
import type { GraphEdge, GraphNode } from "./graph.ts";
import { similarityEdges, tfidfVectors } from "./tfidf.ts";

// ---------------------------------------------------------------------------
// CLI args
// ---------------------------------------------------------------------------

interface Args {
  output: string;
  dryRun: boolean;
  noPreflight: boolean;
}

function parseArgs(argv: readonly string[]): Args {
  const args: Args = { output: "graph-data.json", dryRun: false, noPreflight: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--output") {
      const value = argv[i + 1];
      if (value === undefined) fail("--output requires a path argument");
      args.output = value;
      i++;
    } else if (arg === "--dry-run") {
      args.dryRun = true;
    } else if (arg === "--no-preflight") {
      args.noPreflight = true;
    } else {
      fail(`unknown argument: ${arg}\nusage: notion-graph-sync [--output <path>] [--dry-run] [--no-preflight]`);
    }
  }
  return args;
}

function fail(message: string): never {
  console.error(`error: ${message}`);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Fetch phases
// ---------------------------------------------------------------------------

/** All explicitly-included page ids — these beat pattern excludes. */
function explicitIncludeIds(): Set<string> {
  const ids = new Set<string>();
  for (const hub of INCLUDES.hubPages) ids.add(hub.id);
  for (const id of WORK_INCLUDES.pages) ids.add(id);
  return ids;
}

interface FetchedData {
  nodes: GraphNode[];
  hierarchyEdges: GraphEdge[];
  texts: Map<string, string>;
}

async function fetchAll(client: NotionClient): Promise<FetchedData> {
  const explicit = explicitIncludeIds();
  const patterns = EXCLUDES.namePatterns;
  const nodes: GraphNode[] = [];
  const edges: GraphEdge[] = [];
  const texts = new Map<string, string>();

  // --- Phase 1: database rows -> note nodes --------------------------------
  const dataSourceByNodeId = new Map<string, string>(); // node id -> data source id
  for (const ds of INCLUDES.dataSources) {
    process.stderr.write(`querying database ${ds.label} (${ds.id})\n`);
    let rows: DbRow[] = [];
    try {
      rows = await client.queryDatabase(ds.id);
    } catch (err) {
      fail(`failed to query database "${ds.label}" (${ds.id}): ${String(err)}`);
    }
    for (const row of rows) {
      if (!shouldIncludeNode(row.title, row.id, patterns, explicit)) continue;
      nodes.push({
        id: row.id,
        label: row.title,
        kind: "note",
        cluster: ds.cluster,
        tags: row.tags,
        createdAt: row.createdTime,
        updatedAt: row.lastEditedTime,
      });
      dataSourceByNodeId.set(row.id, ds.id);
      // Body text for TF-IDF similarity (first-level blocks, capped) —
      // without it ~all row nodes have empty vectors and similarity edges die.
      await client.fetchRowText(row.id, texts);
    }
  }

  // --- Phase 2: hub subtrees ------------------------------------------------
  for (const hub of INCLUDES.hubPages) {
    process.stderr.write(`drilling hub (${hub.id}, depth ${hub.depth})\n`);
    let tree: TreeNode;
    try {
      tree = await client.fetchSubtree(hub.id, hub.depth, texts);
    } catch (err) {
      fail(`failed to drill hub ${hub.id}: ${String(err)}`);
    }

    // Flatten with pattern filtering; collect kept ids for metadata fetch.
    // An excluded name drops its whole branch ("applied everywhere").
    const kept: { id: string; title: string; isContainer: boolean; parentId?: string }[] = [];
    const visit = (node: TreeNode, parentId?: string): void => {
      if (!shouldIncludeNode(node.title, node.id, patterns, explicit)) return;
      kept.push({ id: node.id, title: node.title, isContainer: node.isContainer, parentId });
      for (const child of node.children) visit(child, node.id);
    };
    visit(tree);

    // Timestamps need one metadata request per kept node (titles already came
    // free from child_page blocks).
    const metaById = new Map<string, { created: string; updated: string }>();
    for (const item of kept) {
      try {
        const meta = await client.pageMeta(item.id);
        metaById.set(item.id, { created: meta.createdTime, updated: meta.lastEditedTime });
      } catch {
        metaById.set(item.id, { created: "", updated: "" }); // deleted/private mid-tree
      }
    }

    for (const item of kept) {
      const times = metaById.get(item.id);
      nodes.push({
        id: item.id,
        label: item.title,
        kind: item.isContainer ? "hub" : "note",
        cluster: hub.cluster,
        tags: [],
        createdAt: times?.created ?? "",
        updatedAt: times?.updated ?? "",
      });
      if (item.parentId !== undefined && metaById.has(item.parentId)) {
        edges.push({ source: item.parentId, target: item.id, type: "hierarchy", weight: 1.0 });
      }
    }
  }

  // --- Phase 3: work pages --------------------------------------------------
  for (const id of WORK_INCLUDES.pages) {
    if (!shouldIncludeNode(id, id, patterns, explicit)) continue;
    let title = "";
    let created = "";
    let updated = "";
    try {
      const meta = await client.pageMeta(id);
      title = meta.title;
      created = meta.createdTime;
      updated = meta.lastEditedTime;
    } catch (err) {
      fail(`failed to fetch work page ${id}: ${String(err)}`);
    }
    nodes.push({
      id,
      label: title,
      kind: "note",
      cluster: WORK_INCLUDES.cluster,
      tags: [],
      createdAt: created,
      updatedAt: updated,
    });
    // Body text for TF-IDF only.
    await client.fetchPageText(id, texts);
  }

  // --- Phase 4: optional hub -> database-row hierarchy edges -----------------
  const nodeIds = new Set(nodes.map((n) => n.id));
  for (const [hubId, dsIds] of Object.entries(HUB_TO_DATA_SOURCES)) {
    if (!nodeIds.has(hubId)) continue;
    for (const node of nodes) {
      const sourceId = dataSourceByNodeId.get(node.id);
      if (sourceId !== undefined && dsIds.includes(sourceId)) {
        edges.push({ source: hubId, target: node.id, type: "hierarchy", weight: 1.0 });
      }
    }
  }

  return { nodes, hierarchyEdges: edges, texts };
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));

  const token = process.env.NOTION_TOKEN;
  if (token === undefined || token.trim().length === 0) {
    fail(
      "NOTION_TOKEN environment variable is not set.\n" +
        "Create an integration at https://www.notion.so/my-integrations and export its secret:\n" +
        "  export NOTION_TOKEN=secret_...   (provided via sops in production)",
    );
  }

  const client = new NotionClient(token.trim());

  // --- Preflight visibility check (before ANY other request) ----------------
  // Notion 404s (not 403s) unshared content, so we distinguish "wrong
  // endpoint" from "not shared" up front via a fully-paginated /search.
  if (!args.noPreflight) {
    process.stderr.write("preflight: checking integration visibility via /search...\n");
    const accessible = await client.searchAccessibleIds();
    const results = diffPreflight(collectExpectedEntries(), accessible);
    if (!printPreflight(results)) {
      console.error(PREFLIGHT_GUIDANCE);
      process.exit(1);
    }
  }

  const { nodes, hierarchyEdges, texts } = await fetchAll(client);

  // --- Edges ----------------------------------------------------------------
  const tag = tagEdges(nodes, THRESHOLDS.tagJaccardMin);

  const vectors = tfidfVectors(texts);
  const sim = similarityEdges(vectors, THRESHOLDS.similarityMin, THRESHOLDS.similarityTopK)
    .map((e) => ({ source: e.source, target: e.target, type: "similarity" as const, weight: Math.round(e.weight * 1000) / 1000 }));

  const graph = assembleGraph(nodes, [...hierarchyEdges, ...tag, ...sim]);

  // --- Harmlessness gate (before ANY write) ---------------------------------
  const violations: GateViolation[] = runGate(graph);
  const gatePassed = violations.length === 0;

  // --- Report ---------------------------------------------------------------
  const byCluster = new Map<string, number>();
  const byKind = new Map<string, number>();
  for (const node of graph.nodes) {
    byCluster.set(node.cluster, (byCluster.get(node.cluster) ?? 0) + 1);
    byKind.set(node.kind, (byKind.get(node.kind) ?? 0) + 1);
  }
  const byType = new Map<string, number>();
  for (const edge of graph.edges) {
    byType.set(edge.type, (byType.get(edge.type) ?? 0) + 1);
  }

  console.log("== notion-graph-sync summary ==");
  console.log(`nodes: ${graph.nodes.length}`);
  for (const [cluster, count] of [...byCluster].sort()) console.log(`  cluster ${cluster}: ${count}`);
  for (const [kind, count] of [...byKind].sort()) console.log(`  kind ${kind}: ${count}`);
  console.log(`edges: ${graph.edges.length}`);
  for (const [type, count] of [...byType].sort()) console.log(`  ${type}: ${count}`);
  console.log(`gate: ${gatePassed ? "PASS" : `FAIL (${violations.length} violations)`}`);
  for (const v of violations.slice(0, 20)) {
    console.log(`  violation at ${v.path}: ${v.reason}`);
  }
  if (violations.length > 20) console.log(`  ...and ${violations.length - 20} more`);

  if (!gatePassed) {
    fail("harmlessness gate failed — nothing written");
  }

  if (args.dryRun) {
    console.log(`dry-run: would write ${args.output} (nothing written)`);
    return;
  }

  const json = JSON.stringify(graph, null, 2) + "\n";
  const { writeFile } = await import("node:fs/promises");
  await writeFile(args.output, json, "utf8");
  console.log(`wrote ${args.output} (${json.length} bytes)`);
}

main().catch((err: unknown) => {
  console.error(`error: ${String(err)}`);
  process.exit(1);
});
