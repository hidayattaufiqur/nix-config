/**
 * TF-IDF + cosine similarity, dependency-free.
 *
 * Pipeline per doc: tokenize (lowercase alphanum runs) -> drop stopwords ->
 * tf = raw count -> tfidf = tf * idf -> L2-normalize. Cosine of two
 * normalized vectors is a plain dot product.
 */

/** ~50 common English stopwords. Not exhaustive by design. */
export const STOPWORDS: ReadonlySet<string> = new Set([
  "a", "an", "and", "are", "as", "at", "be", "but", "by", "for",
  "from", "has", "have", "he", "her", "his", "i", "if", "in", "is",
  "it", "its", "of", "on", "or", "she", "that", "the", "their", "them",
  "then", "there", "these", "they", "this", "to", "was", "were", "will", "with",
  "you", "your", "we", "our", "not", "no", "do", "does", "did", "so",
]);

export type Vec = Map<string, number>;

/** Lowercase alphanum tokens with stopwords removed and 1-char junk dropped. */
export function tokenize(text: string): string[] {
  const raw = text.toLowerCase().match(/[a-z0-9]+/g) ?? [];
  return raw.filter((t) => t.length > 1 && !STOPWORDS.has(t));
}

function l2Normalize(v: Vec): Vec {
  let norm = 0;
  for (const w of v.values()) norm += w * w;
  norm = Math.sqrt(norm);
  if (norm === 0) return new Map();
  const out = new Map<string, number>();
  for (const [k, w] of v) out.set(k, w / norm);
  return out;
}

/**
 * Build one L2-normalized TF-IDF vector per doc.
 * @param docs docId -> raw page text (text stays in memory only)
 */
export function tfidfVectors(docs: ReadonlyMap<string, string>): Map<string, Vec> {
  const n = docs.size;
  const tokenized = new Map<string, Map<string, number>>();
  const df = new Map<string, number>();

  for (const [id, text] of docs) {
    const counts = new Map<string, number>();
    for (const tok of tokenize(text)) {
      counts.set(tok, (counts.get(tok) ?? 0) + 1);
    }
    for (const term of counts.keys()) {
      df.set(term, (df.get(term) ?? 0) + 1);
    }
    tokenized.set(id, counts);
  }

  // Smoothed idf so unseen-at-query terms never blow up: ln((N+1)/(df+1)) + 1.
  const vectors = new Map<string, Vec>();
  for (const [id, counts] of tokenized) {
    const v = new Map<string, number>();
    for (const [term, tf] of counts) {
      const idf = Math.log((n + 1) / ((df.get(term) ?? 0) + 1)) + 1;
      v.set(term, tf * idf);
    }
    vectors.set(id, l2Normalize(v));
  }
  return vectors;
}

/** Cosine similarity of two L2-normalized vectors (= dot product). */
export function cosine(a: Vec, b: Vec): number {
  if (a.size > b.size) return cosine(b, a); // iterate the smaller side
  let sum = 0;
  for (const [k, w] of a) {
    const bw = b.get(k);
    if (bw !== undefined) sum += w * bw;
  }
  return sum;
}

export interface SimEdge {
  source: string;
  target: string;
  weight: number;
}

/**
 * Similarity edges: keep pairs scoring >= threshold that appear in EITHER
 * endpoint's top-K neighbor list (symmetrized). Each pair emitted once,
 * ordered source < target for determinism.
 */
export function similarityEdges(
  vectors: ReadonlyMap<string, Vec>,
  threshold: number,
  topK: number,
): SimEdge[] {
  const inTopK = new Map<string, Set<string>>();
  for (const [id, vec] of vectors) {
    if (vec.size === 0) continue;
    const scored: { other: string; score: number }[] = [];
    for (const [other, ovec] of vectors) {
      if (other === id || ovec.size === 0) continue;
      const score = cosine(vec, ovec);
      if (score >= threshold) scored.push({ other, score });
    }
    scored.sort((x, y) => y.score - x.score || x.other.localeCompare(y.other));
    inTopK.set(id, new Set(scored.slice(0, topK).map((s) => s.other)));
  }

  const edges = new Map<string, SimEdge>();
  for (const [id, neighbors] of inTopK) {
    for (const other of neighbors) {
      // Keep if in either's top-5; emit once with canonical ordering.
      if (!(inTopK.get(other)?.has(id) ?? false) && other < id) continue;
      const [source, target] = id < other ? [id, other] : [other, id];
      const key = `${source}\u0000${target}`;
      if (!edges.has(key)) {
        edges.set(key, { source, target, weight: cosine(vectors.get(id)!, vectors.get(other)!) });
      }
    }
  }
  return [...edges.values()].sort((x, y) =>
    x.source.localeCompare(y.source) || x.target.localeCompare(y.target),
  );
}
