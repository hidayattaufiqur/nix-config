/**
 * Name-based exclusion filters.
 *
 * Rule: an explicit include (any id listed in INCLUDES/WORK_INCLUDES) always
 * beats a pattern exclude. This is what keeps the "Archives" HUB page alive
 * even though /^archives?$/i is a banned pattern for everything else.
 */

/** True if the title matches ANY exclude pattern. */
export function matchesExclude(name: string, patterns: readonly RegExp[]): boolean {
  return patterns.some((p) => p.test(name));
}

/**
 * Should this item become a node?
 * Explicit ids pass unconditionally; everything else must not match a pattern.
 */
export function shouldIncludeNode(
  name: string,
  id: string,
  patterns: readonly RegExp[],
  explicitIds: ReadonlySet<string>,
): boolean {
  if (explicitIds.has(id)) return true;
  return !matchesExclude(name, patterns);
}
