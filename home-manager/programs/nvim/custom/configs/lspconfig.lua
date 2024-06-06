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
  "tsserver",
  "nil_ls"
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

lspconfig.tsserver.setup{
  on_attach = on_attach,
  capabilities = capabilities,
}

lspconfig.basedpyright.setup{
  on_attach = on_attach,
  capabilities = capabilities,
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

return M
