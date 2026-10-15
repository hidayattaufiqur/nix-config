// Local 9router patch: a per-model 400 must not abort the whole combo.
//
// Upstream `open-sse/services/combo.js` returns the failing leg's response when
// `checkFallbackError()` says shouldFallback:false. That verdict is written for
// ACCOUNT rotation (a request-scoped 4xx says nothing about the credential, so
// don't cool the account down) and it is right there — but in the combo loop the
// next leg is a different MODEL, so a model-scoped 400 like
//
//   [400] {"type":"error","error":{"type":"api_error",
//          "message":"Upstream request failed: Model is unavailable."}}
//
// killed the chain (observed: leg 2/9, surfaced as a 400 to hermes, which then
// switched provider away from 9router entirely).
//
// Fix: in the combo path only, when shouldFallback:false, still advance to the
// next combo model — just skip the account-cooldown bookkeeping (which lives in
// src/sse/services/auth.js markAccountUnavailable, untouched). 401/402/403/404/429
// and the ERROR_RULES text rules are upstream of this branch and unchanged.
//
// FAIL-CLOSED: exits non-zero if the upstream block is not found exactly once, so
// an upstream refactor can never silently drop this patch out of the image.
//
// Usage: node 9router-combo-fallback-patch.mjs <path-to>/open-sse/services/combo.js
import fs from "fs";

const file = process.argv[2];
if (!file) {
  console.error("usage: 9router-combo-fallback-patch.mjs <open-sse/services/combo.js>");
  process.exit(2);
}

const OLD = `      // Check if should fallback to next model
      const { shouldFallback, cooldownMs } = checkFallbackError(result.status, errorText);

      if (!shouldFallback) {
        log.warn("COMBO", \`Model \${modelStr} failed (no fallback)\`, { status: result.status });
        return result;
      }
`;

const NEW = `      // Check if should fallback to next model.
      // checkFallbackError answers the account-rotation question (cool this
      // credential down?), but the combo loop always moves to the next MODEL —
      // a request/model-scoped 4xx (e.g. upstream "Model is unavailable.") must
      // degrade to leg N+1, not abort the chain. [local patch: combo-400-fallthrough]
      const { shouldFallback, cooldownMs } = checkFallbackError(result.status, errorText);

      if (!shouldFallback) {
        // No account cooldown for this class of error (auth.js owns that), but
        // the next combo model is a different model — keep chaining.
        lastError = errorText || String(result.status);
        if (!lastStatus) lastStatus = result.status;
        log.warn("COMBO", \`Model \${modelStr} failed, trying next (no account cooldown)\`, { status: result.status });
        continue;
      }
`;

const src = fs.readFileSync(file, "utf8");
const found = src.split(OLD).length - 1;
if (found !== 1) {
  console.error(`[combo-400-fallthrough] FAIL: expected the upstream abort block exactly once in ${file}, found ${found}. Upstream changed — rebase this patch.`);
  process.exit(1);
}

const out = src.replace(OLD, NEW);
if (!out.includes("trying next (no account cooldown)") || out.includes("failed (no fallback)")) {
  console.error("[combo-400-fallthrough] FAIL: post-replace verification failed");
  process.exit(1);
}

fs.writeFileSync(file, out);
console.log(`[combo-400-fallthrough] patched ${file}`);
