local M = {}

-- export on_attach & capabilities
M.on_attach = function(client, bufnr)
  local function opts(desc)
    return { buffer = bufnr, desc = "LSP " .. desc }
  end

  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts "Go to declaration")
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts "Go to definition")
  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts "hover information")
  vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts "Go to implementation")
  vim.keymap.set("n", "<leader>sh", vim.lsp.buf.signature_help, opts "Show signature help")
  vim.keymap.set("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, opts "Add workspace folder")
  vim.keymap.set("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, opts "Remove workspace folder")

  vim.keymap.set("n", "<leader>wl", function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, opts "List workspace folders")

  vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, opts "Go to type definition")

  vim.keymap.set("n", "<leader>ra", function()
    require "nvchad.lsp.renamer"()
  end, opts "NvRenamer")

  vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts "Code action")
  vim.keymap.set("n", "gr", vim.lsp.buf.references, opts "Show references")

  -- setup signature popup
  if Nvconfig.ui.lsp.signature and client.server_capabilities.signatureHelpProvider then
    require("nvchad.lsp.signature").setup(client, bufnr)
  end
end

-- disable semanticTokens
M.on_init = function(client, _)
  if client.supports_method "textDocument/semanticTokens" then
    client.server_capabilities.semanticTokensProvider = nil
  end
end

M.capabilities = vim.lsp.protocol.make_client_capabilities()

M.capabilities.textDocument.completion.completionItem = {
  documentationFormat = { "markdown", "plaintext" },
  snippetSupport = true,
  preselectSupport = true,
  insertReplaceSupport = true,
  labelDetailsSupport = true,
  deprecatedSupport = true,
  commitCharactersSupport = true,
  tagSupport = { valueSet = { 1 } },
  resolveSupport = {
    properties = {
      "documentation",
      "detail",
      "additionalTextEdits",
    },
  },
}

M.defaults = function()
  dofile(vim.g.base46_cache .. "lsp")
  require "nvchad.lsp"

  require("lspconfig").lua_ls.setup {
    on_attach = M.on_attach,
    capabilities = M.capabilities,
    on_init = M.on_init,

    settings = {
      Lua = {
        diagnostics = {
          globals = { "vim" },
        },
        workspace = {
          library = {
            [vim.fn.expand "$VIMRUNTIME/lua"] = true,
            [vim.fn.expand "$VIMRUNTIME/lua/vim/lsp"] = true,
            [vim.fn.stdpath "data" .. "/lazy/ui/nvchad_types"] = true,
            [vim.fn.stdpath "data" .. "/lazy/lazy.nvim/lua/lazy"] = true,
          },
          maxPreload = 100000,
          preloadFileSize = 10000,
        },
      },
    },
  }
end
