// Behavioural check for the combo-400-fallthrough patch (card t_54fa8e8b).
//
// Asserts against the RUNTIME artifact, so run it inside a built image:
//
//   docker run --rm -i --entrypoint /usr/local/bin/node \
//     <image> --input-type=module - < 9router-combo-fallback-check.mjs
//
// Expected: ALL CHECKS PASSED (exit 0). On an unpatched image the 400 cases in
// checks 1 and 3 fail, which is the negative control that proves this test bites.
//
// Import path is intentionally the in-container path: this is a post-build check.
const { handleComboChat } = await import("/app/open-sse/services/combo.js");

const logs = [];
const log = { info: (t, m) => logs.push(`INFO ${m}`), warn: (t, m) => logs.push(`WARN ${m}`) };
const mkResp = (status, message) => ({
  ok: status >= 200 && status < 300, status, statusText: message,
  clone() { return { json: async () => ({ error: { type: "api_error", message } }) }; }
});
const run = async (legs) => {
  const tried = [];
  const res = await handleComboChat({
    body: {}, models: legs.map(([m]) => m), log,
    handleSingleModel: async (b, m) => {
      tried.push(m);
      const [, status, msg] = legs.find(([n]) => n === m);
      return mkResp(status, msg);
    }
  });
  return { tried, res };
};

let fail = 0;
const chk = (cond, msg) => { if (cond) console.log("ok:", msg); else { console.log("FAIL:", msg); fail++; } };

// 1. the observed prod bug: leg 1 returns a model-scoped 400 -> leg 2 serves
let { tried, res } = await run([
  ["oc/union-alpha", 400, "Upstream request failed: Model is unavailable."],
  ["cmc/deepseek/deepseek-v4.1-flash", 200, "ok"],
]);
console.log("legs tried:", JSON.stringify(tried));
chk(tried.length === 2 && res.status === 200, "400 leg advanced to leg 2 and succeeded");
chk(logs.some((l) => l.includes("Trying model 2/2")), "log shows 'Trying model 2/2'");
chk(!logs.some((l) => l.includes("failed (no fallback)")), "old abort log absent");

// 2. account-scoped statuses keep chaining
for (const st of [401, 402, 403, 404, 429]) {
  ({ tried, res } = await run([[`dead/${st}`, st, "upstream"], ["cmc/ok", 200, "ok"]]));
  chk(tried.length === 2 && res.status === 200, `${st} leg advanced to leg 2`);
}

// 3. every leg 400 -> surfaced status, not a crash or a hang
({ tried, res } = await run([
  ["a/dead", 400, "Model is unavailable."],
  ["b/dead", 400, "Model is unavailable."],
]));
chk(tried.length === 2, "exhausted all legs on repeated 400");
chk(res.status === 400, `exhausted combo returns 400 (got ${res.status})`);

// 4. a healthy first leg still short-circuits
({ tried, res } = await run([["cmc/ok", 200, "ok"], ["cmc/never", 500, "boom"]]));
chk(tried.length === 1 && res.status === 200, "healthy leg 1 short-circuits");

console.log(fail === 0 ? "ALL CHECKS PASSED" : `${fail} CHECK(S) FAILED`);
process.exit(fail === 0 ? 0 : 1);
