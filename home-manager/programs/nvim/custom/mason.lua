local mason = require('plugins.configs.mason')

mason.ensure_installed = {
  "lua_ls",
  "gopls",
  "golangci_lint_ls",
  "html",
  "basedpyright",
  "ts_ls",
  "nil_ls",
  "jsonls",
  "clangd",
  "cmake",
  "cmake_format",
  "rust_analyzer",
  "rust_analyzer_code_actions",
  "sumneko_lua",
  "pyright",
  "yamlls",
  "dockerls",
  "bashls",
  "sqlls",
  -- TODO: add java mason
}
