/**
 * Preflight visibility check.
 *
 * Notion returns 404 (not 403) for content the integration cannot see, so a
 * failing sync is ambiguous: wrong endpoint vs not-shared. This check runs
 * POST /v1/search first and diffs the token's accessible ids against every
 * configured include, printing an ACCESSIBLE / NOT-SHARED table before any
 * other request is made. Kept in its own module so tests can import it
 * without executing main.ts's CLI entry point.
 */

import { INCLUDES, WORK_INCLUDES } from "./config.ts";
import { normalizeId } from "./notion.ts";

export interface PreflightEntry {
  kind: "dataSource" | "hubPage" | "workPage";
  label: string;
  id: string;
}

export function collectExpectedEntries(): PreflightEntry[] {
  const out: PreflightEntry[] = [];
  for (const ds of INCLUDES.dataSources) {
    out.push({ kind: "dataSource", label: ds.label, id: ds.id });
  }
  INCLUDES.hubPages.forEach((hub, i) => {
    out.push({ kind: "hubPage", label: `hub #${i + 1}`, id: hub.id });
  });
  WORK_INCLUDES.pages.forEach((id, i) => {
    out.push({ kind: "workPage", label: `work page #${i + 1}`, id });
  });
  return out;
}

export interface PreflightResult {
  entry: PreflightEntry;
  accessible: boolean;
}

export function diffPreflight(
  expected: readonly PreflightEntry[],
  accessibleIds: ReadonlySet<string>,
): PreflightResult[] {
  return expected.map((entry) => ({ entry, accessible: accessibleIds.has(normalizeId(entry.id)) }));
}

const GUIDANCE = `
Some configured entries are NOT visible to this integration — Notion will
return 404 (not 403) for them, so the sync would fail confusingly.

Fix on the Notion side:
  1. Open each NOT-SHARED entry's parent page in Notion.
  2. Click the ... menu (top-right) -> Connections -> connect this
     integration.
  3. Sharing a top-level parent (e.g. 'Second Brain') inherits downward to
     all sub-pages and databases — connecting at the root usually fixes
     everything in one click.
  4. Re-run notion-graph-sync.

To skip this check (not recommended): pass --no-preflight.
`;

/** Prints the ACCESSIBLE / NOT-SHARED table; true iff everything is shared. */
export function printPreflight(results: readonly PreflightResult[]): boolean {
  const width = Math.max(...results.map((r) => r.entry.label.length), "LABEL".length);
  console.log(`preflight: ${"STATUS".padEnd(12)} ${"KIND".padEnd(12)} LABEL`);
  for (const r of results) {
    const status = r.accessible ? "ACCESSIBLE" : "NOT-SHARED";
    console.log(
      `  ${status.padEnd(12)} ${r.entry.kind.padEnd(12)} ${r.entry.label.padEnd(width)} ${r.entry.id}`,
    );
  }
  const missing = results.filter((r) => !r.accessible);
  if (missing.length > 0) {
    console.error(`\npreflight: ${missing.length} of ${results.length} entries NOT-SHARED`);
    return false;
  }
  console.log(`preflight: all ${results.length} entries accessible`);
  return true;
}

export { GUIDANCE as PREFLIGHT_GUIDANCE };
