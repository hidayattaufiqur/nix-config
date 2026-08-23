/**
 * Unit tests for the pure logic: harmlessness gate, TF-IDF similarity,
 * name-pattern excludes, explicit-include-beats-pattern, tag jaccard.
 * Run: npm test  (node --test, zero deps)
 */

import test from "node:test";
import assert from "node:assert/strict";

import { runGate } from "../src/gate.ts";
import { tokenize, tfidfVectors, cosine, similarityEdges } from "../src/tfidf.ts";
import { matchesExclude, shouldIncludeNode } from "../src/filters.ts";
import { EXCLUDES } from "../src/config.ts";
import { jaccard, tagEdges, assembleGraph } from "../src/graph.ts";
import type { GraphNode } from "../src/graph.ts";

// ---------------------------------------------------------------------------
// Harmlessness gate
// ---------------------------------------------------------------------------

function cleanNode(overrides: Partial<GraphNode> = {}): GraphNode {
  return {
    id: "abc123",
    label: "A perfectly fine title",
    kind: "note",
    cluster: "personal",
    tags: [],
    createdAt: "2026-01-01T00:00:00.000Z",
    updatedAt: "2026-01-02T00:00:00.000Z",
    ...overrides,
  };
}

const cleanGraph = {
  meta: { generatedAt: "2026-08-23T00:00:00.000Z", version: 1 },
  nodes: [cleanNode()],
  edges: [{ source: "abc123", target: "def456", type: "tag", weight: 0.5 }],
};

test("gate passes a clean graph", () => {
  assert.deepEqual(runGate(cleanGraph), []);
});

test("gate catches a leaked url key", () => {
  const leaky = structuredClone(cleanGraph) as Record<string, unknown>;
  (leaky.nodes as Record<string, unknown>[])[0]!.url = "https://app.notion.so/secret-page-abc123";
  const violations = runGate(leaky);
  assert.ok(violations.some((v) => v.reason.includes("url")), JSON.stringify(violations));
});

test("gate catches notion.so / notion.com string in any value", () => {
  for (const fragment of ["see https://www.notion.so/my-page", "https://app.notion.com/x"]) {
    const leaky = structuredClone(cleanGraph);
    leaky.nodes[0]!.label = fragment;
    const violations = runGate(leaky);
    assert.ok(
      violations.some((v) => v.reason.includes("banned substring")),
      `"${fragment}" should trip the gate`,
    );
  }
});

test("gate catches banned client codename case-insensitively", () => {
  const leaky = structuredClone(cleanGraph);
  leaky.nodes[0]!.label = "OSMT sprint retro notes";
  const violations = runGate(leaky);
  assert.ok(violations.some((v) => v.reason.includes("banned substring")));
});

test("gate bans employer-name substrings in any casing or position", () => {
  for (const fragment of ["Nine Dots Consulting sync", "NINE DOTS roadmap", "DDB backend notes", "re-ddb-migration"]) {
    const leaky = structuredClone(cleanGraph);
    leaky.nodes[0]!.label = fragment;
    const violations = runGate(leaky);
    assert.ok(
      violations.some((v) => v.reason.includes("banned substring")),
      `"${fragment}" should trip the gate`,
    );
  }
});

test("gate does NOT banned-substring opaque fields (ids, sources, targets)", () => {
  // Notion UUIDs are random hex — "ddb" appears by chance and is NOT a leak.
  const leaky = structuredClone(cleanGraph);
  leaky.nodes[0]!.id = "a1b2c3d4-e56f-4789-a012-ddb3456789ab";
  leaky.edges[0]!.source = "ddb123";
  leaky.edges[0]!.target = "notion-so-looking-hex-ddbfff";
  assert.deepEqual(runGate(leaky), []);
});

test("gate still length-checks opaque fields (id over maxStringLength fails)", () => {
  const leaky = structuredClone(cleanGraph);
  leaky.nodes[0]!.id = "x".repeat(121);
  const violations = runGate(leaky);
  assert.ok(violations.some((v) => v.reason.includes("exceeds")));
});

test("gate catches over-long string (leaked body fragment)", () => {
  const leaky = structuredClone(cleanGraph);
  leaky.nodes[0]!.label = "x".repeat(121);
  const violations = runGate(leaky);
  assert.ok(violations.some((v) => v.reason.includes("exceeds")));
});

test("gate catches keys outside the schema whitelist", () => {
  const leaky = structuredClone(cleanGraph) as Record<string, unknown>;
  (leaky.nodes as Record<string, unknown>[])[0]!.bodyText = "leaked paragraph ".repeat(10);
  const violations = runGate(leaky);
  assert.ok(violations.some((v) => v.reason.includes("whitelist")));
});

test("gate catches nested url key deep in the tree", () => {
  const leaky = { meta: { generatedAt: "x", version: 1 }, nodes: [], edges: [], extra: { link: { Url: "y" } } };
  const violations = runGate(leaky);
  assert.ok(violations.some((v) => v.path.includes("Url") || v.path.includes("url")));
});

// ---------------------------------------------------------------------------
// TF-IDF / similarity
// ---------------------------------------------------------------------------

test("tokenize lowercases, strips punctuation, drops stopwords", () => {
  assert.deepEqual(tokenize("The Risk-Management and RISK plans!"), ["risk", "management", "risk", "plans"]);
});

test("similarity threshold: related docs pass, unrelated docs fail", () => {
  const docs = new Map([
    ["a", "trading journal stop loss risk management position sizing rules"],
    ["b", "trading journal stop loss strategy review risk management checklist"],
    ["c", "chocolate cake recipe butter flour sugar oven minutes"],
  ]);
  const vectors = tfidfVectors(docs);
  const simAB = cosine(vectors.get("a")!, vectors.get("b")!);
  const simAC = cosine(vectors.get("a")!, vectors.get("c")!);

  assert.ok(simAB >= 0.25, `expected similar pair >= 0.25, got ${simAB}`);
  assert.ok(simAC < 0.25, `expected dissimilar pair < 0.25, got ${simAC}`);

  const edges = similarityEdges(vectors, 0.25, 5);
  const hasAB = edges.some(
    (e) => (e.source === "a" && e.target === "b") || (e.source === "b" && e.target === "a"),
  );
  const hasAC = edges.some(
    (e) => (e.source === "a" && e.target === "c") || (e.source === "c" && e.target === "a"),
  );
  assert.ok(hasAB, "similar pair should produce an edge");
  assert.ok(!hasAC, "dissimilar pair must not produce an edge");
});

test("similarity topK cap respected and symmetrized", () => {
  // hub is strongly similar to 7 satellites; only top-5 may survive.
  const docs = new Map<string, string>([["hub", "alpha beta gamma delta epsilon zeta eta theta"]]);
  const topics = [
    "alpha beta gamma",
    "beta gamma delta",
    "gamma delta epsilon",
    "delta epsilon zeta",
    "epsilon zeta eta",
    "zeta eta theta",
    "eta theta alpha",
  ];
  topics.forEach((t, i) => docs.set(`s${i}`, `${t} ${t} ${t}`));
  const edges = similarityEdges(tfidfVectors(docs), 0.05, 5);
  const hubDegree = edges.filter((e) => e.source === "hub" || e.target === "hub").length;
  assert.ok(hubDegree <= 5, `hub degree ${hubDegree} exceeds topK=5`);
});

// ---------------------------------------------------------------------------
// Name-pattern excludes
// ---------------------------------------------------------------------------

const patterns = EXCLUDES.namePatterns;

test("name patterns exclude matching titles", () => {
  for (const name of ["tracked", "Assignments", "Assignment", "Grades 2026", "OSMT backlog", "untitled", "Weekly meet", "Nine Dots — Q3 roadmap", "nine dots clipping", "NINE DOTS retro"]) {
    assert.ok(matchesExclude(name, patterns), `"${name}" should be excluded`);
  }
});

test("name patterns do NOT exclude legitimate titles", () => {
  for (const name of ["Reading List", "Trading Strategies", "Second Brain", "Archive of ideas 2019", "polka dots history"]) {
    assert.ok(!matchesExclude(name, patterns), `"${name}" should be kept`);
  }
});

test("explicit include beats pattern exclude (Archives hub)", () => {
  const archivesHubId = "29e3a9b5-52b6-49bf-b4a2-2182862cabf8";
  const explicitIds = new Set([archivesHubId]);
  assert.ok(shouldIncludeNode("Archives", archivesHubId, patterns, explicitIds));
  // Same name without explicit id -> dropped.
  assert.ok(!shouldIncludeNode("Archives", "some-other-id", patterns, explicitIds));
});

// ---------------------------------------------------------------------------
// Tag edges
// ---------------------------------------------------------------------------

test("jaccard threshold filters weak tag overlap", () => {
  const n = (id: string, tags: string[]): GraphNode => ({ ...cleanNode({ id }), tags });
  // a-b: 1/3 ≈ 0.333 < 0.34 dropped; a-c: 2/4 = 0.5 kept; b-c: 1/3 dropped.
  const nodes = [n("a", ["x", "y", "z"]), n("b", ["x"]), n("c", ["x", "y", "w"])];
  const edges = tagEdges(nodes, 0.34);
  assert.equal(edges.length, 1);
  assert.equal(edges[0]!.source, "a");
  assert.equal(edges[0]!.target, "c");
  assert.equal(jaccard(new Set(["x"]), new Set(["x"])), 1);
});

// ---------------------------------------------------------------------------
// Label truncation
// ---------------------------------------------------------------------------

test("assembleGraph truncates overlong labels deterministically", () => {
  const long = "An extremely long article title about distributed systems. ".repeat(3);
  const graph1 = assembleGraph([cleanNode({ label: long })], []);
  const graph2 = assembleGraph([cleanNode({ label: long })], []);
  const label = graph1.nodes[0]!.label;
  assert.ok(label.length <= 120, `truncated label length ${label.length} exceeds 120`);
  assert.ok(label.endsWith("…"), "truncated label must end with ellipsis");
  assert.equal(label, graph2.nodes[0]!.label, "truncation must be deterministic");
});

test("short labels pass through untouched; custom max respected", () => {
  const graph = assembleGraph([cleanNode({ label: "Short one" })], [], 10);
  assert.equal(graph.nodes[0]!.label, "Short one");
  const capped = assembleGraph([cleanNode({ label: "abcdefghijk" })], [], 10);
  assert.equal(capped.nodes[0]!.label, "abcdefghi…");
  assert.equal(capped.nodes[0]!.label.length, 10);
});

// ---------------------------------------------------------------------------
// Deterministic output
// ---------------------------------------------------------------------------

test("assembleGraph sorts nodes by id and edges by source+target", () => {
  const graph = assembleGraph(
    [cleanNode({ id: "zzz" }), cleanNode({ id: "aaa" })],
    [
      { source: "b", target: "c", type: "tag", weight: 1 },
      { source: "a", target: "z", type: "similarity", weight: 1 },
      { source: "a", target: "m", type: "hierarchy", weight: 1 },
    ],
  );
  assert.deepEqual(graph.nodes.map((n) => n.id), ["aaa", "zzz"]);
  assert.deepEqual(
    graph.edges.map((e) => `${e.source}${e.target}`),
    ["am", "az", "bc"],
  );
});
