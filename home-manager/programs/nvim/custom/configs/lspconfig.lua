local configs = require("plugins.configs.lspconfig")
local on_attach = configs.on_attach
local capabilities = configs.capabilities

local lspconfig = require "lspconfig"
local servers = { "html", "cssls", "clangd", "golangci-lint-langserver", " typescript-language-server" }

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

-- if not configs.golangcilsp then
--  	configs.golangcilsp = {
-- 		default_config = {
-- 			cmd = {'golangci-lint-langserver'},
-- 			root_dir = lspconfig.util.root_pattern('.git', 'go.mod'),
-- 			init_options = {
-- 					command = { "golangci-lint", "run", "--enable-all", "--disable", "lll", "--out-format", "json", "--issues-exit-code=1" };
-- 			}
-- 		};
-- 	}
-- end

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

lspconfig.pyright.setup{
  on_attach = on_attach,
  capabilities = capabilities,
}

lspconfig.nil_ls.setup{
  on_attach = on_attach,
  capabilities = capabilities,
}

-- Without the loop, you would have to manually set up each LSP 
-- 
-- lspconfig.html.setup {
--   on_attach = on_attach,
--   capabilities = capabilities,
-- }
--
-- lspconfig.cssls.setup {
--   on_attach = on_attach,
--   capabilities = capabilities,
-- }

