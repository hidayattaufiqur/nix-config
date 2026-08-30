-- 2026-08-28: migrated to vim.lsp.config (nvim 0.11+)
-- `require("lspconfig").SERVER.setup` is deprecated (see :help lspconfig-nvim-0.11)
-- Use vim.lsp.config + vim.lsp.enable. Keep fallback for older nvim/lspconfig.
local configs = require("plugins.configs.lspconfig")
local on_attach = configs.on_attach
local capabilities = configs.capabilities

-- helper: configure + enable, with fallback to legacy lspconfig
local function setup(server, opts)
  opts = opts or {}
  opts.on_attach = opts.on_attach or on_attach
  opts.capabilities = opts.capabilities or capabilities
  if vim.lsp.config then
    vim.lsp.config(server, opts)
    vim.lsp.enable(server)
  else
    require("lspconfig")[server].setup(opts)
  end
end

-- use vim.fs.root directly (lspconfig.util deprecated, not always available at startup)
local root_pattern = function(...)
  local patterns = { ... }
  return function(fname)
    return vim.fs.root(fname, patterns)
  end
end

-- common servers (de-duplicated; missing servers are silently skipped)
local servers = {
  "html",
  "cssls",
  "clangd",
  "lua_ls",
  "gopls",
  "golangci_lint_ls",
  "basedpyright",
  "ts_ls",
  "nil_ls",
  "astro",
  "cmake",
  "rust_analyzer",
}

for _, lsp in ipairs(servers) do
  -- pcall: server may not be installed / config may not exist (e.g. golangci_lint_ls)
  pcall(setup, lsp, {
    settings = {
      Go = { diagnostics = { globals = { "vim" } } },
    },
  })
end

-- gopls (detailed)
pcall(setup, "gopls", {
  root_dir = root_pattern(".git", "go.mod"),
  flags = { debounce_text_changes = 150 },
  settings = {
    gopls = {
      analyses = {
        nilness = true,
        unusedparams = true,
        unusedwrite = true,
        useany = true,
      },
      gofumpt = true,
      experimentalPostfixCompletions = true,
      staticcheck = true,
      usePlaceholders = true,
    },
  },
  init_options = {
    usePlaceholders = true,
    completeUnimported = true,
    staticcheck = true,
    matcher = "fuzzy",
    semanticTokens = true,
  },
})

pcall(setup, "ts_ls", {})
pcall(setup, "basedpyright", {
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        autoImportCompletions = true,
        logLevel = "hint",
        diagnosticMode = "openFilesOnly",
        useLibraryCodeForTypes = true,
        typeCheckingMode = "basic",
        reportUnusedImport = true,
        reportMissingImports = true,
      },
    },
  },
})

pcall(setup, "nil_ls", {
  autostart = true,
  settings = {
    ["nil"] = {
      testSetting = 42,
      formatting = { command = { "nixpkgs-fmt" } },
    },
  },
})

for _, srv in ipairs({ "astro", "cmake", "clangd", "ccls" }) do
  pcall(setup, srv, {})
end

pcall(setup, "rust_analyzer", {
  settings = {
    ["rust-analyzer"] = { diagnostics = { enable = false } },
  },
})

return {}
