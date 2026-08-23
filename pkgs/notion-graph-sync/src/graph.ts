/**
 * Graph assembly: node/edge models, tag edges, label truncation,
 * deterministic output shape.
 */

import { GATE } from "./config.ts";

export interface GraphNode {
  id: string;
  label: string;
  kind: "hub" | "note";
  cluster: string;
  tags: string[];
  createdAt: string;
  updatedAt: string;
}

export interface GraphEdge {
  source: string;
  target: string;
  type: "hierarchy" | "tag" | "similarity";
  weight: number;
}

export interface Graph {
  meta: { generatedAt: string; version: number };
  nodes: GraphNode[];
  edges: GraphEdge[];
}

/** Jaccard similarity of two tag sets: |A∩B| / |A∪B|. */
export function jaccard(a: ReadonlySet<string>, b: ReadonlySet<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let inter = 0;
  for (const t of a) if (b.has(t)) inter++;
  return inter / (a.size + b.size - inter);
}

/**
 * Tag edges between every pair of nodes sharing enough tags.
 * ponytail: O(n²) pairwise scan — fine for personal-workspace scale
 * (hundreds of nodes); switch to an inverted index per tag if it ever grows.
 */
export function tagEdges(nodes: readonly GraphNode[], minJaccard: number): GraphEdge[] {
  const out: GraphEdge[] = [];
  for (let i = 0; i < nodes.length; i++) {
    const a = nodes[i]!;
    const atags = new Set(a.tags);
    if (atags.size === 0) continue;
    for (let j = i + 1; j < nodes.length; j++) {
      const b = nodes[j]!;
      const weight = jaccard(atags, new Set(b.tags));
      if (weight >= minJaccard) {
        out.push({ source: a.id, target: b.id, type: "tag", weight: Math.round(weight * 1000) / 1000 });
      }
    }
  }
  return out;
}

/**
 * Deterministic label truncation: same input -> same output. Overlong labels
 * (long article/tweet titles) are cut to max chars INCLUDING the "…" suffix,
 * so the gate's length check becomes a pure backstop.
 */
export function truncateLabel(label: string, max: number = GATE.maxLabelLength): string {
  return label.length > max ? label.slice(0, max - 1) + "…" : label;
}

/**
 * Final deterministic graph: nodes sorted by id, edges by source+target(+type
 * as tiebreak), labels truncated to GATE.maxLabelLength. Re-runs produce
 * byte-identical JSON apart from generatedAt, so the artifact diffs cleanly
 * in git.
 */
export function assembleGraph(
  nodes: GraphNode[],
  edges: GraphEdge[],
  maxLabelLength: number = GATE.maxLabelLength,
): Graph {
  const sortedNodes = [...nodes]
    .map((n) => ({ ...n, label: truncateLabel(n.label, maxLabelLength) }))
    .sort((a, b) => a.id.localeCompare(b.id));
  const sortedEdges = [...edges].sort(
    (a, b) =>
      a.source.localeCompare(b.source) ||
      a.target.localeCompare(b.target) ||
      a.type.localeCompare(b.type),
  );
  return {
    meta: { generatedAt: new Date().toISOString(), version: 1 },
    nodes: sortedNodes,
    edges: sortedEdges,
  };
}
