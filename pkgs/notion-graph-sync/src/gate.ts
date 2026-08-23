/**
 * Harmlessness gate — the last line of defense before anything touches disk.
 *
 * Runs on the fully assembled graph object BEFORE serialization/writing.
 * Any violation hard-fails the run with a non-zero exit and nothing written.
 *
 * Checks:
 *   1. No "url" key anywhere in the tree (case-insensitive).
 *   2. No banned substring in HUMAN-MEANINGFUL string values (case-insensitive):
 *      label, cluster, and tags[] items only. Opaque fields (id, source,
 *      target, timestamps) are exempt — Notion UUIDs are random hex and
 *      routinely contain banned fragments ("ddb") by pure chance.
 *   3. No string longer than maxStringLength (titles are short; this catches
 *      leaked body fragments). Length applies to ALL strings, opaque included.
 *   4. Every object's keys are within the schema whitelist.
 */

import { GATE } from "./config.ts";

export interface GateViolation {
  /** JSON-ish path of the offending value, e.g. nodes[3].label */
  path: string;
  reason: string;
}

const META_KEYS: ReadonlySet<string> = new Set(["generatedAt", "version"]);
const NODE_KEYS: ReadonlySet<string> = new Set([
  "id", "label", "kind", "cluster", "tags", "createdAt", "updatedAt",
]);
const EDGE_KEYS: ReadonlySet<string> = new Set(["source", "target", "type", "weight"]);

/** Keys whose string values are human-authored and substring-checked. */
const CONTENT_KEYS: ReadonlySet<string> = new Set(["label", "cluster", "tags"]);

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function whitelistFor(path: string): ReadonlySet<string> | undefined {
  // Paths look like "", ".meta", ".nodes[0]", ".edges[2].weight"
  if (path === ".meta") return META_KEYS;
  if (path.startsWith(".nodes[")) return NODE_KEYS;
  if (path.startsWith(".edges[")) return EDGE_KEYS;
  return undefined;
}

export function runGate(
  graph: unknown,
  bannedSubstrings: readonly string[] = GATE.bannedSubstrings,
  maxStringLength: number = GATE.maxStringLength,
): GateViolation[] {
  const violations: GateViolation[] = [];
  const lowerBanned = bannedSubstrings.map((b) => b.toLowerCase());

  function walk(value: unknown, path: string, content: boolean): void {
    const whitelist = whitelistFor(path);
    if (isRecord(value)) {
      for (const [key, child] of Object.entries(value)) {
        if (key.toLowerCase() === "url") {
          violations.push({ path: `${path}.${key}`, reason: 'forbidden "url" key' });
          continue;
        }
        if (whitelist && !whitelist.has(key)) {
          violations.push({ path: `${path}.${key}`, reason: `key outside schema whitelist` });
        }
        walk(child, `${path}.${key}`, CONTENT_KEYS.has(key));
      }
      return;
    }
    if (Array.isArray(value)) {
      value.forEach((item, i) => walk(item, `${path}[${i}]`, content));
      return;
    }
    if (typeof value === "string") {
      if (content) {
        const lower = value.toLowerCase();
        for (const banned of lowerBanned) {
          if (lower.includes(banned)) {
            violations.push({ path, reason: `banned substring "${banned}"` });
          }
        }
      }
      if (value.length > maxStringLength) {
        violations.push({
          path,
          reason: `string length ${value.length} exceeds ${maxStringLength} (possible leaked body text)`,
        });
      }
    }
  }

  walk(graph, "", false);
  return violations;
}
