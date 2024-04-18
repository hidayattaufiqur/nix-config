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
    "hrsh7th/nvim-cmp",
    dependencies = {
      {
        "zbirenbaum/copilot-cmp",
        config = function()
          require("copilot_cmp").setup()
        end,
      },
    },
    opts = {
      mapping = {
        -- go to next placeholder in the snippet
        ["<C-n>"] = cmp.mapping(function(fallback)
          if luasnip.jumpable(1) then
            luasnip.jump(1)
          else
            fallback()
          end
        end, { "i", "s" }),
        -- go to previous placeholder in the snippet
        ["<C-p>"] = cmp.mapping(function(fallback)
          if luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<C-u>"] = cmp.mapping.scroll_docs(-4),
        ["<C-d>"] = cmp.mapping.scroll_docs(4),
        ["<C-y>"] = cmp.mapping.complete(),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<CR>"] = cmp.mapping.confirm {
          behavior = cmp.ConfirmBehavior.Replace,
          select = true,
        },
        -- Select next item
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          elseif has_words_before() then
            cmp.complete()
          else
            fallback()
          end
        end, { "i", "s" }),
        -- Select prev item
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      },
      sources = {
        { name = "nvim_lsp", group_index = 2 },
        { name = "copilot", group_index = 2 },
        { name = "luasnip", group_index = 2 },
        { name = "buffer", group_index = 2 },
        { name = "nvim_lua", group_index = 2 },
        { name = "path", group_index = 2 },
      },
    },
  },

  -- modify the `lspconfig` configuration:
  {
    "neovim/nvim-lspconfig",
     config = function()
        require "plugins.configs.lspconfig"
        require "custom.configs.lspconfig"
     end,
  },
  {
      "github/copilot.vim",
      lazy = false,
      config = function()
        -- Mapping tab is already used by NvChad
        vim.g.copilot_no_tab_map = true;
        vim.g.copilot_assume_mapped = true;
        vim.g.copilot_tab_fallback = "";
        -- The mapping is set to other key, see custom/lua/mappings
        -- or run <leader>ch to see copilot mapping section
      end
  }
}
