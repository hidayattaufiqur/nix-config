/**
 * API-layer tests: stubbed global fetch covering both endpoint flavors
 * (modern /data_sources/{id}/query and legacy /databases/{id} fallback),
 * the pinned Notion-Version header, 404 error messaging, and the pure
 * preflight diff logic.
 * Run: npm test  (node --test, zero deps)
 */

import test from "node:test";
import assert from "node:assert/strict";

import { NotionApiError, NotionClient, normalizeId } from "../src/notion.ts";
import { RUNTIME } from "../src/config.ts";
import { collectExpectedEntries, diffPreflight } from "../src/preflight.ts";

// --- fetch stubbing ----------------------------------------------------------

type Handler = (path: string, init?: RequestInit) => Response;

/** Route table keyed by path (no origin). Throws on unexpected requests. */
function withFetch(routes: Record<string, Handler>, fn: () => Promise<void>): Promise<void> {
  const orig = globalThis.fetch;
  RUNTIME.rateLimitMs = 0; // no throttle in tests
  globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
    const path = String(input).replace(/^https?:\/\/[^/]+(\/v1)?/, "");
    const handler = routes[path];
    if (!handler) {
      throw new Error(`unexpected request in test stub: ${init?.method ?? "GET"} ${path}`);
    }
    return handler(path, init);
  }) as typeof fetch;
  return fn().finally(() => {
    globalThis.fetch = orig;
    RUNTIME.rateLimitMs = 350;
  });
}

const jsonRes = (body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), { status });

const page = (id: string, title: string) => ({
  object: "page",
  id,
  created_time: "2026-01-01T00:00:00.000Z",
  last_edited_time: "2026-01-02T00:00:00.000Z",
  properties: {
    Title: { type: "title", title: [{ plain_text: title }] },
    Tags: { type: "multi_select", multi_select: [{ name: "alpha" }] },
  },
});

// --- endpoint flavors --------------------------------------------------------

test("queryDatabase queries /data_sources/{id}/query with pinned version header", async () => {
  let sawVersion = "";
  let sawAuth = "";
  await withFetch(
    {
      "/data_sources/ds-1/query": (_path, init) => {
        sawVersion = new Headers(init?.headers).get("Notion-Version") ?? "";
        sawAuth = new Headers(init?.headers).get("Authorization") ?? "";
        return jsonRes({ results: [page("row-1", "Idea one")], has_more: false });
      },
    },
    async () => {
      const rows = await new NotionClient("secret_test").queryDatabase("ds-1");
      assert.equal(rows.length, 1);
      assert.equal(rows[0]!.id, "row-1");
      assert.equal(rows[0]!.title, "Idea one");
      assert.equal(rows[0]!.tags[0], "alpha");
      assert.equal(sawVersion, RUNTIME.notionVersion);
      assert.ok(RUNTIME.notionVersion >= "2025-09-03", "version must be >= 2025-09-03");
      assert.equal(sawAuth, "Bearer secret_test");
    },
  );
});

test("legacy database id falls back to GET /databases/{id} and merges all data sources", async () => {
  let dbLookups = 0;
  await withFetch(
    {
      "/data_sources/db-1/query": () => jsonRes({ results: [] }, 404),
      "/databases/db-1": () => {
        dbLookups++;
        return jsonRes({
          object: "database",
          data_sources: [{ id: "ds-a" }, { id: "ds-b" }],
        });
      },
      "/data_sources/ds-a/query": () =>
        jsonRes({ results: [page("row-a1", "From A")], has_more: false }),
      "/data_sources/ds-b/query": () =>
        jsonRes({
          results: [page("row-b1", "B one"), page("row-b2", "B two")],
          has_more: false,
        }),
    },
    async () => {
      const rows = await new NotionClient("secret_test").queryDatabase("db-1");
      assert.deepEqual(
        rows.map((r) => r.id).sort(),
        ["row-a1", "row-b1", "row-b2"],
      );
      assert.equal(dbLookups, 1, "database lookup should happen exactly once");
    },
  );
});

test("non-404 errors do NOT trigger the legacy fallback", async () => {
  await withFetch(
    {
      "/data_sources/db-x/query": () => jsonRes({ code: "internal_server_error" }, 500),
    },
    async () => {
      await assert.rejects(
        () => new NotionClient("secret_test").queryDatabase("db-x"),
        (err: unknown) => err instanceof NotionApiError && err.status === 500,
      );
    },
  );
});

test("404 error message names both causes (id flavor vs not-shared)", async () => {
  await withFetch(
    {
      "/data_sources/gone/query": () => jsonRes({}, 404),
      "/databases/gone": () => jsonRes({}, 404),
    },
    async () => {
      await assert.rejects(
        () => new NotionClient("secret_test").queryDatabase("gone"),
        (err: unknown) => {
          assert.ok(err instanceof NotionApiError);
          assert.equal(err.status, 404);
          assert.match(err.message, /DATA-SOURCE ids/);
          assert.match(err.message, /data_sources\/\{id\}\/query/);
          assert.match(err.message, /Connections/);
          return true;
        },
      );
    },
  );
});

test("searchAccessibleIds paginates and normalizes ids", async () => {
  await withFetch(
    {
      "/search": (_path, init) => {
        const body = JSON.parse(String(init?.body ?? "{}")) as { start_cursor?: string };
        if (body.start_cursor === undefined) {
          return jsonRes({
            results: [{ object: "page", id: "AbCd-Ef01" }],
            has_more: true,
            next_cursor: "c2",
          });
        }
        return jsonRes({
          results: [{ object: "data_source", id: "11223344-5566-7788-99aa-bbccddeeff00" }],
          has_more: false,
        });
      },
    },
    async () => {
      const ids = await new NotionClient("secret_test").searchAccessibleIds();
      assert.ok(ids.has(normalizeId("AbCd-Ef01")));
      assert.ok(ids.has("112233445566778899aabbccddeeff00"));
      assert.equal(ids.size, 2);
    },
  );
});

// --- row body text (TF-IDF input) --------------------------------------------

test("fetchRowText collects first-level block text, skips child_page, caps blocks", async () => {
  const many = Array.from({ length: 60 }, (_, i) => ({
    object: "block",
    id: `b${i}`,
    type: "paragraph",
    paragraph: { rich_text: [{ plain_text: `para ${i}` }] },
  }));
  await withFetch(
    {
      "/blocks/row-1/children?page_size=100": () =>
        jsonRes({
          results: [
            ...many.slice(0, 10),
            { object: "block", id: "child", type: "child_page", child_page: { title: "Sub" } },
            ...many.slice(10),
          ],
          has_more: false,
        }),
    },
    async () => {
      const texts = new Map<string, string>();
      await new NotionClient("secret_test").fetchRowText("row-1", texts);
      const text = texts.get("row-1") ?? "";
      assert.match(text, /para 0\b/);
      assert.doesNotMatch(text, /para 59\b/, "blocks beyond the cap must be dropped");
      assert.doesNotMatch(text, /Sub/, "child_page titles must not leak into text");
      assert.ok(!texts.has("child"));
    },
  );
});

test("fetchRowText stores nothing for an empty page", async () => {
  await withFetch(
    {
      "/blocks/empty/children?page_size=100": () => jsonRes({ results: [], has_more: false }),
    },
    async () => {
      const texts = new Map<string, string>();
      await new NotionClient("secret_test").fetchRowText("empty", texts);
      assert.equal(texts.size, 0);
    },
  );
});

// --- preflight diff (pure logic) ---------------------------------------------

const entries = [
  { kind: "dataSource" as const, label: "Idea Dump", id: "11ee485f-e563-4f69-86b7-3ed7be9babd0" },
  { kind: "workPage" as const, label: "work page #1", id: "2684188b-6f6a-809a-ab21-c67d84f444aa" },
];

test("preflight diff marks everything accessible when search sees all ids", () => {
  const accessible = new Set(entries.map((e) => normalizeId(e.id)));
  const results = diffPreflight(entries, accessible);
  assert.ok(results.every((r) => r.accessible));
});

test("preflight diff matches across dash/no-dash id forms", () => {
  // Token returned undashed; config uses dashed.
  const accessible = new Set(["11ee485fe5634f6986b73ed7be9babd0"]);
  const [ideaDump] = diffPreflight([entries[0]!], accessible);
  assert.ok(ideaDump!.accessible);
});

test("preflight diff flags NOT-SHARED entries", () => {
  const accessible = new Set([normalizeId(entries[0]!.id)]); // second one missing
  const results = diffPreflight(entries, accessible);
  assert.equal(results.filter((r) => !r.accessible).length, 1);
  assert.equal(results[1]!.entry.label, "work page #1");
});

test("collectExpectedEntries covers all configured includes", () => {
  const all = collectExpectedEntries();
  const byKind = (k: string) => all.filter((e) => e.kind === k).length;
  assert.equal(byKind("dataSource"), 13); // INCLUDES.dataSources length
  assert.equal(byKind("hubPage"), 5); // INCLUDES.hubPages length
  assert.equal(byKind("workPage"), 16); // WORK_INCLUDES.pages length
});
