-- 2026-08-28: migrated to nvim 0.12 + nvim-treesitter `main` (breaking rewrite).
-- Old API `require("nvim-treesitter.configs").setup` removedupstream.
-- Parsers are now nix-managed via `vimPlugins.nvim-treesitter.withPlugins`
-- in `home-manager/programs/nvim/default.nix`. This module only enables
-- vim.treesitter per-filetype.
-- See https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md

local M = {}

-- Keep this list in sync with `withPlugins` in default.nix.
-- If you add a language, add it in both places and rebuild.
M.ensure_installed = {
  "lua",
  "typescript",
  "javascript",
  "json",
  "html",
  "css",
  "scss",
  "yaml",
  "toml",
  "rust",
  "go",
  "gomod",
  "gosum",
  "nix",
  "proto",
  "python",
  "bash",
  "c",
  "cpp",
  "java",
  "graphql",
  "tsx",
  "markdown",
  "sql",
  "dockerfile",
  "todotxt",
  "cmake",
  "tmux",
  "astro",
}

function M.setup()
  -- Highlight, folds, indent are now native vim.treesitter (nvim 0.12).
  -- Enable for every filetype where a parser is available.
  local group = vim.api.nvim_create_augroup("TreesitterMain", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(args)
      local buf = args.buf
      -- pcall: some buffers (e.g. TelescopePrompt) have no parser
      local ok = pcall(vim.treesitter.start, buf)
      if not ok then return end

      -- experimental treesitter indent (replaces nvim-treesitter indent module)
      -- guarded: not every language has indents.scm
      pcall(function()
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end)

      -- folds
      vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
      vim.wo.foldmethod = "expr"
    end,
  })

  -- Optional: also mirror legacy `incremental_selection`/`textobjects` via
  -- built-in keymaps if users rely on them. Minimal setup; extensible.
end

return M
