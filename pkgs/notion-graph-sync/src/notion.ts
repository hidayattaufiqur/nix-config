/**
 * Minimal Notion API v1 client over global fetch — no SDK dependency.
 *
 * - Throttled to ~3 req/sec (config RUNTIME.rateLimitMs).
 * - Retries HTTP 429 honoring Retry-After.
 * - Only extracts: ids, titles, tags, timestamps, and (in-memory only) block
 *   text for TF-IDF. Nothing here ever reaches the emitted artifact except
 *   through main.ts's node builder, which copies whitelisted fields only.
 */

import { RUNTIME } from "./config.ts";

const API_BASE = RUNTIME.apiBase;

// --- minimal response shapes (unknown-narrowed, zero `any`) -----------------

interface RichTextItem {
  plain_text?: unknown;
}

interface Property {
  type?: unknown;
  title?: RichTextItem[];
  multi_select?: { name?: unknown }[];
}

export interface PageLike {
  id: string;
  created_time?: unknown;
  last_edited_time?: unknown;
  properties?: Record<string, Property>;
}

interface BlockBody {
  rich_text?: RichTextItem[];
}

interface Block {
  object?: unknown;
  id?: string;
  type?: string;
  has_children?: boolean;
  child_page?: { title?: unknown };
  [key: string]: unknown;
}

interface ListResponse<T> {
  results?: T[];
  has_more?: boolean;
  next_cursor?: string | null;
}

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function asString(v: unknown): string {
  return typeof v === "string" ? v : "";
}

/** Canonical id form for comparisons: lowercase, no dashes. */
export function normalizeId(id: string): string {
  return id.replaceAll("-", "").toLowerCase();
}

/** Concatenated plain_text of a block's rich_text array ("" if none). */
export function blockRichText(block: Block): string {
  const type = block.type;
  if (!type) return "";
  const body: unknown = block[type];
  if (!isRecord(body)) return "";
  const rt = (body as BlockBody).rich_text;
  if (!Array.isArray(rt)) return "";
  return rt.map((item) => asString(item?.plain_text)).join("");
}

export class NotionApiError extends Error {
  readonly status: number;

  constructor(status: number, path: string, statusText: string) {
    super(
      status === 404
        ? `Notion API 404 on ${path.split("?")[0]}: ${statusText}. Two common causes: ` +
          `(1) endpoint/id-flavor mismatch — since API version 2025-09-03 configured ids are ` +
          `DATA-SOURCE ids queried at /v1/data_sources/{id}/query; a legacy database_id can be ` +
          `resolved via GET /v1/databases/{id} -> data_sources[].id; ` +
          `(2) the integration cannot see this content — Notion returns 404 (not 403) for pages ` +
          `not shared with it: in Notion, open the parent page -> ... menu -> Connections -> ` +
          `connect this integration (sharing a top-level parent inherits downward).`
        : `Notion API ${status} on ${path.split("?")[0]}: ${statusText}`,
    );
    this.name = "NotionApiError";
    this.status = status;
  }
}

export interface DbRow {
  id: string;
  title: string;
  tags: string[];
  createdTime: string;
  lastEditedTime: string;
}

export interface PageMeta {
  id: string;
  title: string;
  createdTime: string;
  lastEditedTime: string;
}

export interface TreeNode {
  id: string;
  title: string;
  children: TreeNode[];
  /** true = intermediate container page -> rendered as a hub node */
  isContainer: boolean;
}

function pageTitleFromProperties(page: PageLike): string {
  for (const prop of Object.values(page.properties ?? {})) {
    if (prop.type === "title" && Array.isArray(prop.title)) {
      return prop.title.map((t) => asString(t.plain_text)).join("");
    }
  }
  return "";
}

function tagsFromProperties(page: PageLike): string[] {
  for (const prop of Object.values(page.properties ?? {})) {
    if (prop.type === "multi_select" && Array.isArray(prop.multi_select)) {
      return prop.multi_select.map((s) => asString(s.name)).filter((n) => n.length > 0);
    }
  }
  return [];
}

/** One DbRow per query-result page (id/title/tags/timestamps). */
function rowFromPage(p: unknown): DbRow {
  const page = p as PageLike;
  return {
    id: page.id,
    title: pageTitleFromProperties(page),
    tags: tagsFromProperties(page),
    createdTime: asString(page.created_time),
    lastEditedTime: asString(page.last_edited_time),
  };
}

export class NotionClient {
  private lastRequestAt = 0;
  private readonly token: string;

  constructor(token: string) {
    this.token = token;
  }

  private async throttle(): Promise<void> {
    const waitMs = this.lastRequestAt + RUNTIME.rateLimitMs - Date.now();
    if (waitMs > 0) await new Promise((resolve) => setTimeout(resolve, waitMs));
    this.lastRequestAt = Date.now();
  }

  private async request(path: string, body?: unknown): Promise<unknown> {
    let attempt = 0;
    for (;;) {
      await this.throttle();
      const res = await fetch(`${API_BASE}${path}`, {
        method: body === undefined ? "GET" : "POST",
        headers: {
          "Authorization": `Bearer ${this.token}`,
          "Notion-Version": RUNTIME.notionVersion,
          ...(body === undefined ? {} : { "Content-Type": "application/json" }),
        },
        body: body === undefined ? undefined : JSON.stringify(body),
      });
      if (res.status === 429 && attempt < RUNTIME.maxRetries) {
        const retryAfter = Number(res.headers.get("retry-after") ?? "1");
        await new Promise((r) => setTimeout(r, Math.max(retryAfter, 1) * 1000));
        attempt++;
        continue;
      }
      if (!res.ok) {
        // Error bodies may contain request URLs — keep them out of any
        // structured output; stderr-only diagnostics are fine.
        throw new NotionApiError(res.status, path, res.statusText);
      }
      return res.json();
    }
  }

  /** Paginated GET/POST list endpoint; returns every result across cursors. */
  private async listAll(path: string, body?: Record<string, unknown>): Promise<unknown[]> {
    const out: unknown[] = [];
    let cursor: string | undefined;
    do {
      const payload = cursor === undefined ? body : { ...body, start_cursor: cursor };
      const res = await this.request(path, payload) as ListResponse<unknown>;
      out.push(...(res.results ?? []));
      cursor = res.has_more === true ? res.next_cursor ?? undefined : undefined;
    } while (cursor !== undefined);
    return out;
  }

  /** Query one data source (modern endpoint, API >= 2025-09-03). */
  async queryDataSource(dataSourceId: string): Promise<DbRow[]> {
    const pages = await this.listAll(`/data_sources/${dataSourceId}/query`, { page_size: 100 });
    return pages.map(rowFromPage);
  }

  /**
   * Query a configured id regardless of flavor.
   *
   * Tries the modern POST /v1/data_sources/{id}/query first — under API
   * version 2025-09-03+ the ids in config.ts are data-source ids. If that
   * 404s, treats the id as a legacy database_id: GET /v1/databases/{id},
   * resolve its data_sources[].id list, query each and merge the rows.
   */
  async queryDatabase(id: string): Promise<DbRow[]> {
    try {
      return await this.queryDataSource(id);
    } catch (err) {
      if (!(err instanceof NotionApiError) || err.status !== 404) throw err;
      const db = await this.request(`/databases/${id}`) as { data_sources?: { id?: unknown }[] };
      const dsIds = (db.data_sources ?? [])
        .map((d) => asString(d.id))
        .filter((s) => s.length > 0);
      if (dsIds.length === 0) {
        throw new Error(`database ${id} resolved but exposes no data sources`);
      }
      const rows: DbRow[] = [];
      for (const dsId of dsIds) rows.push(...(await this.queryDataSource(dsId)));
      return rows;
    }
  }

  /**
   * Every page/data-source id visible to this token, via fully-paginated
   * POST /v1/search with an empty query. Used by the preflight visibility
   * check in main.ts — Notion 404s (not 403s) unshared content, so this is
   * the only way to distinguish "wrong endpoint" from "not shared".
   */
  async searchAccessibleIds(): Promise<Set<string>> {
    const results = await this.listAll("/search", {});
    const ids = new Set<string>();
    for (const r of results) {
      if (isRecord(r) && typeof r.id === "string") ids.add(normalizeId(r.id));
    }
    return ids;
  }

  /** Page metadata: title + timestamps (one request). */
  async pageMeta(pageId: string): Promise<PageMeta> {
    const page = await this.request(`/pages/${pageId}`) as PageLike;
    return {
      id: page.id,
      title: pageTitleFromProperties(page),
      createdTime: asString(page.created_time),
      lastEditedTime: asString(page.last_edited_time),
    };
  }

  /** All direct children blocks of a page/block (paginated). */
  async blockChildren(blockId: string): Promise<Block[]> {
    const blocks = await this.listAll(`/blocks/${blockId}/children?page_size=100`);
    return blocks as Block[];
  }

  /**
   * Recursively drill child_page blocks up to maxDepth levels below pageId.
   * Non-child_page block text is accumulated into `texts` (docId -> text)
   * for TF-IDF and is NEVER emitted. Children at the depth frontier become
   * leaf nodes using titles from the parent's block list (no extra requests).
   *
   * ponytail: does not descend into non-child_page containers (columns,
   * nested lists); their text is still collected, their sub-pages are not.
   * Add recursion on has_children blocks if sub-page coverage matters.
   */
  async fetchSubtree(
    pageId: string,
    maxDepth: number,
    texts: Map<string, string>,
  ): Promise<TreeNode> {
    const meta = await this.pageMeta(pageId);
    return this.drill(pageId, meta.title, maxDepth, texts);
  }

  private async drill(
    pageId: string,
    title: string,
    depthRemaining: number,
    texts: Map<string, string>,
  ): Promise<TreeNode> {
    const blocks = await this.blockChildren(pageId);
    const children: TreeNode[] = [];
    let textAcc = "";

    for (const block of blocks) {
      if (block.type === "child_page" && block.id !== undefined) {
        const childTitle = asString(block.child_page?.title);
        if (depthRemaining > 0) {
          children.push(await this.drill(block.id, childTitle, depthRemaining - 1, texts));
        } else {
          // Frontier leaf: free title, no drilling.
          children.push({ id: block.id, title: childTitle, children: [], isContainer: false });
        }
      } else {
        textAcc += blockRichText(block) + "\n";
      }
    }

    if (textAcc.trim().length > 0) texts.set(pageId, textAcc);
    return { id: pageId, title, children, isContainer: children.length > 0 };
  }

  /**
   * Full block text of a plain page (all nesting levels of rich_text-bearing
   * blocks). In-memory TF-IDF input only — never emitted.
   */
  async fetchPageText(pageId: string, texts: Map<string, string>): Promise<void> {
    let textAcc = "";
    const walk = async (blockId: string): Promise<void> => {
      const blocks = await this.blockChildren(blockId);
      for (const block of blocks) {
        if (block.type === "child_page") continue; // subtree handled elsewhere
        textAcc += blockRichText(block) + "\n";
        if (block.has_children === true && block.id !== undefined) {
          await walk(block.id);
        }
      }
    };
    await walk(pageId);
    if (textAcc.trim().length > 0) texts.set(pageId, textAcc);
  }

  /**
   * First-level block text of a database-row page, capped at
   * RUNTIME.rowTextMaxBlocks blocks, non-recursive. First-level blocks give
   * enough TF-IDF signal without the recursive request cost. In-memory only.
   *
   * ponytail: non-recursive + block cap; recurse into has_children and raise
   * the cap if row-level similarity ever comes up thin.
   */
  async fetchRowText(pageId: string, texts: Map<string, string>): Promise<void> {
    const blocks = await this.blockChildren(pageId);
    let textAcc = "";
    for (const block of blocks.slice(0, RUNTIME.rowTextMaxBlocks)) {
      if (block.type === "child_page") continue;
      textAcc += blockRichText(block) + "\n";
    }
    if (textAcc.trim().length > 0) texts.set(pageId, textAcc);
  }
}
