const http = require("http");
const path = require("path");
const fs = require("fs");
const crypto = require("crypto");
const { pathToFileURL } = require("url");

// === AgentRouter header-spoof plugin (spike) ===
const AGENTROUTER_HOST = "agentrouter.org";
const INJECTED_HEADERS = {
  "User-Agent": "claude-cli/1.0.108 (external, cli)",
  "anthropic-version": "2023-06-01",
  "anthropic-beta": "claude-code-20250219,oauth-2025-04-20",
  "anthropic-dangerous-direct-browser-access": "true",
  "x-app": "cli",
  "x-stainless-lang": "js",
  "x-stainless-package-version": "0.55.1",
  "x-stainless-os": "Windows",
  "x-stainless-arch": "x64",
  "x-stainless-runtime": "node",
  "x-stainless-runtime-version": "v22.0.0",
};
function isAgentRouterUrl(url) {
  try {
    const p = typeof url === "string" ? new URL(url) : new URL(url.url ?? url.href ?? String(url));
    return p.hostname === AGENTROUTER_HOST || p.hostname.endsWith("." + AGENTROUTER_HOST);
  } catch { return false; }
}
function installWrapper(chain) {
  const wrapped = async function (input, init) {
    try {
      const url = typeof input === "string" || input instanceof URL ? input : input?.url;
      const isAr = url && isAgentRouterUrl(url);
      if (isAr) {
        const headers = new Headers(init?.headers ?? (input && input.headers) ?? undefined);
        for (const [k, v] of Object.entries(INJECTED_HEADERS)) headers.set(k, v);
        const newInit = { ...(init ?? {}), headers };
        try { fs.appendFileSync("/tmp/inject.txt", "INJECTED " + String(url) + " " + new Date().toISOString() + "\n"); } catch {}
        return chain(input instanceof Request ? new Request(input, newInit) : input, newInit);
      }
    } catch {}
    return chain(input, init);
  };
  wrapped.__agentrouterPatched = true;
  return wrapped;
}
function ensurePatched() {
  const current = globalThis.fetch;
  try {
    fs.appendFileSync("/tmp/ensure-count.txt", (current && current.__agentrouterPatched ? "already " : "wrap ") + new Date().toISOString() + "\n");
  } catch {}
  if (current && !current.__agentrouterPatched) {
    globalThis.fetch = installWrapper(current);
  }
}
try {
  fs.writeFileSync("/tmp/patch-ran.txt", "patch loaded " + new Date().toISOString() + "\n");
} catch {}
ensurePatched();
const iv = setInterval(ensurePatched, 1000);
iv.unref && iv.unref();
// === end AgentRouter patch ===

const origCreate = http.createServer.bind(http);

const PEER_TOKEN = crypto.randomBytes(24).toString("hex");
process.env.NINEROUTER_PEER_TOKEN = PEER_TOKEN;

let backgroundRefreshStarted = false;

function startBackgroundTokenRefreshFromCustomServer() {
  if (backgroundRefreshStarted) return;
  backgroundRefreshStarted = true;
  const modPath = path.join(__dirname, "src", "sse", "services", "backgroundTokenRefresh.js");
  import(pathToFileURL(modPath).href)
    .then((m) => {
      try { m.startBackgroundTokenRefresh(); } catch (e) { console.error("[BackgroundTokenRefresh] start failed:", e && e.message ? e.message : e); }
      const stop = () => { try { m.stopBackgroundTokenRefresh(); } catch { /* ignore */ } };
      process.once("SIGINT", stop);
      process.once("SIGTERM", stop);
    })
    .catch((e) => { if (process.env.DEBUG_BACKGROUND_TOKEN_REFRESH) console.error("[BackgroundTokenRefresh] import failed:", e && e.message ? e.message : e); });
}

http.createServer = (...args) => {
  const handler = args.find((a) => typeof a === "function");
  const rest = args.filter((a) => typeof a !== "function");
  if (!handler) return origCreate(...args);
  const wrapped = (req, res) => {
    const socketIp = req.socket && req.socket.remoteAddress ? req.socket.remoteAddress : "";
    const xff = req.headers["x-forwarded-for"];
    const xRealIp = req.headers["x-real-ip"];
    const viaProxy = !!(xff || xRealIp);
    const isLoopbackProxy = socketIp === "127.0.0.1" || socketIp === "::1" || socketIp === "::ffff:127.0.0.1";
    const proxyIp = xRealIp || (xff ? String(xff).split(",")[0].trim() : "");
    const ip = isLoopbackProxy && proxyIp ? proxyIp : socketIp;
    delete req.headers["x-9r-real-ip"];
    delete req.headers["x-forwarded-for"];
    delete req.headers["x-9r-via-proxy"];
    delete req.headers["x-9r-peer-token"];
    req.headers["x-9r-real-ip"] = ip;
    req.headers["x-9r-peer-token"] = PEER_TOKEN;
    if (viaProxy) req.headers["x-9r-via-proxy"] = "1";
    return handler(req, res);
  };
  const server = origCreate(...rest, wrapped);
  server.once("listening", () => { startBackgroundTokenRefreshFromCustomServer(); });
  const origEmit = server.emit;
  server.emit = function (event, ...eventArgs) {
    const [req, socket, head] = eventArgs;
    if (event !== "upgrade" || String(req.headers.upgrade || "").toLowerCase() !== "h2c") {
      return origEmit.call(this, event, ...eventArgs);
    }
    const contentLength = Number(req.headers["content-length"] || 0);
    if (!Number.isSafeInteger(contentLength) || contentLength < 0) { socket.destroy(); return true; }
    const chunks = [head];
    let received = head.length;
    const serve = () => {
      const replay = new http.IncomingMessage(socket);
      Object.assign(replay, { method: req.method, url: req.url, headers: req.headers, complete: true });
      if (received) replay.push(Buffer.concat(chunks, received).subarray(0, contentLength));
      replay.push(null);
      const res = new http.ServerResponse(replay);
      res.shouldKeepAlive = false;
      res.assignSocket(socket);
      res.once("finish", () => socket.end());
      Promise.resolve().then(() => wrapped(replay, res)).catch((error) => { console.error("Failed to downgrade h2c request", error); socket.destroy(); });
    };
    if (received >= contentLength) serve();
    else {
      socket.on("data", function readBody(chunk) {
        chunks.push(chunk);
        received += chunk.length;
        if (received < contentLength) return;
        socket.off("data", readBody);
        serve();
      });
      socket.resume();
    }
    delete req.headers.upgrade;
    delete req.headers["http2-settings"];
    req.headers.connection = "close";
    return true;
  };
  return server;
};

if (require.main === module) {
  const standalone = path.join(__dirname, "server.js");
  if (fs.existsSync(standalone)) { require(standalone); }
  else {
    const nextBin = require.resolve("next/dist/bin/next");
    process.argv = [process.argv[0], nextBin, "start", ...process.argv.slice(2)];
    require(nextBin);
  }
}
