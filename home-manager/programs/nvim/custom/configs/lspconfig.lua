local configs = require("plugins.configs.lspconfig")
local on_attach = configs.on_attach
local capabilities = configs.capabilities

local lspconfig = require "lspconfig"

local M = {}

M.opts = { inlay_hints = { enabled = true } }

local servers = {
  "html",
  "cssls",
  "clangd",
  "lua_ls",
  "gopls",
  "golangci_lint_ls",
  "html",
  "basedpyright",
  "ts_ls",
  "nil_ls",
  "astro"
}

for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities,
    settings = {
			Go = {
				diagnostics = {
					globals = {"vim"},
				}
			}
		}
  }
end

 lspconfig.gopls.setup {
    on_attach = on_attach,
    capabilities = capabilities,
    root_dir = lspconfig.util.root_pattern(".git", "go.mod"),
    flags = {
       debounce_text_changes = 150,
    },
    settings = {
       gopls = {
          analyses = {
            nilness = true,
            unusedparams = true,
            unusedwrite = true,
            useany = true
          },
          gofumpt = true,
          experimentalPostfixCompletions = true,
          staticcheck = true,
          usePlaceholders = true,
       },
    },

    -- Enable virtual text wrapping for diagnostics
    -- Adjust the 'virtual_text_max_width' value as needed
    init_options = {
       usePlaceholders = true,
       completeUnimported = true,
       staticcheck = true,
       matcher = "fuzzy",
       -- diagnosticCaching = true,
       -- useWorkspaceFolders = true,
       -- symbolCache = { enabled = true },
       semanticTokens = true,
       -- experimentalWorkspaceModule = true,
       -- virtualText = {
       --     enabled = true,
       --     prefix = "",
       --     spacing = 0,
       --     max_width = 120, -- Adjust this value based on your preference
       -- },
    },
 }

lspconfig.ts_ls.setup{
  on_attach = on_attach,
  capabilities = capabilities,
}

lspconfig.basedpyright.setup{
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        autoImportCompletions = true,
        logLevel = "hint",
        diagnosticMode = "openFilesOnly",
        useLibraryCodeForTypes = true,
        typeCheckingMode = "strict",
        reportUnusedImport = true,
        reportMissingImports = true,
      },
   },
  }
}

lspconfig.nil_ls.setup{
  on_attach = on_attach,
  capabilities = capabilities,
  autostart = true,
  settings = {
    ['nil'] = {
      testSetting = 42,
      formatting = {
        command = { "nixpkgs-fmt" },
      },
    }
  }
}

lspconfig.astro.setup{
  on_attach = on_attach,
  capabilities = capabilities,
}

lspconfig.cmake.setup{
  on_attach = on_attach,
  capabilities = capabilities,
}

lspconfig.clangd.setup{
  on_attach = on_attach,
  capabilities = capabilities,
}

lspconfig.ccls.setup{
  on_attach = on_attach,
  capabilities = capabilities,
}

lspconfig.rust_analyzer.setup{
  settings = {
    ['rust-analyzer'] = {
      diagnostics = {
        enable = false;
      }
    }
  }
}

-- TODO: add java lsp

return M
