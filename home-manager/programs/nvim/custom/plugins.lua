---@diagnostic disable: different-requires
local plugins = {
  -- ... all your other plugins ...
  {
    "zbirenbaum/copilot.lua",
    lazy = false,
    event = "InsertEnter",
    cmd = "Copilot",
    build = ":Copilot auth",
    config = function()
      local opts = require("custom.configs.copilot").opts
      require("copilot").setup(opts)
    end,
  },

  {
    "Pocco81/auto-save.nvim",
    lazy = false,
    config = function()
      require("custom.configs.autosave")
    end,
  }
  -- {
  --   "hrsh7th/nvim-cmp",
  --   dependencies = {
  --     {
  --       "zbirenbaum/copilot-cmp",
  --       config = function()
  --         require("copilot_cmp").setup()
  --       end,
  --     },
  --   },
  --   opts = {
  --     sources = {
  --       { name = "nvim_lsp", group_index = 2 },
  --       { name = "copilot", group_index = 2 },
  --       { name = "luasnip", group_index = 2 },
  --       { name = "buffer", group_index = 2 },
  --       { name = "nvim_lua", group_index = 2 },
  --       { name = "path", group_index = 2 },
  --     },
  --   },
  -- },

  -- modify the `lspconfig` configuration:
  -- {
  --   "neovim/nvim-lspconfig",
  --    config = function()
  --       require "plugins.configs.lspconfig"
  --       require "custom.configs.lspconfig"
  --    end,
  -- },
   -- GitHub Copilot
  -- {
  --   "github/copilot.vim",
  --   lazy = false,
  --   config = function()
  --     -- Mapping tab is already used by NvChad
  --     vim.g.copilot_no_tab_map = true;
  --     vim.g.copilot_assume_mapped = true;
  --     vim.g.copilot_tab_fallback = "";
  --     -- The mapping is set to other key, see custom/lua/mappings
  --     -- or run <leader>ch to see copilot mapping section
  --   end
  -- },

}

return plugins
