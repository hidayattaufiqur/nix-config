---@diagnostic disable: different-requires
local plugins = {
  {
    "folke/todo-comments.nvim",
    lazy = false,
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local opts = require("custom.configs.todo-comments").opts
      require("todo-comments").setup(opts)
    end,
  },
  -- {
  --   "lervag/vimtex",
  --   lazy = false,     -- we don't want to lazy load VimTeX
  --   -- tag = "v2.15", -- uncomment to pin to a specific release
  --   init = function()
  --     -- VimTeX configuration goes here, e.g.
  --     vim.g.vimtex_view_method = "zathura"
  --     vim.cmd[[set conceallevel=2]]
  --     vim.cmd[[let g:tex_conceal='abdmg']]
  --   end
  -- },
  {
    "MunifTanjim/nui.nvim",
    config = function()
        local Menu = require("nui.menu")
        vim.ui.select = function(items, opts, on_choice)
            vim.validate({
                items = { items, 'table', false },
                on_choice = { on_choice, 'function', false },
            })
            opts = opts or {}
            local format_item = opts.format_item or tostring

            Menu({
                relative = "cursor",
                position = {
                    row = 2,
                    col = 0,
                },
                size = {
                    width = 70,
                },
                border = {
                    style = "rounded",
                    text = {
                        top = opts.prompt or "Select an item",
                        top_align = "center",
                    },
                },
            }, {
                lines = (function()
                    ---@type NuiTree.Node[]
                    local selections = {}

                    for _, item in ipairs(items) do
                        if type(item) == "string" then
                            table.insert(selections, Menu.item(item))
                        elseif type(item) == "table" then
                            table.insert(selections, Menu.item(format_item(item), item))
                        end
                    end

                    return selections
                end)(),

                on_close = function()
                    print("Closed")
                end,
                on_submit = function(selected)
                    on_choice(selected)
                end,
            }):mount()
        end

        vim.keymap.set("n", "<leader><leader>", function()
            vim.ui.select({ 'One', 'Two', 'Three' }, {}, function(selected)
                print("Selected: " .. selected)
            end)
        end)
    end,
  },
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
      "MunifTanjim/nui.nvim",
      -- OPTIONAL:
      --   `nvim-notify` is only needed, if you want to use the notification view.
      --   If not available, we use `mini` as the fallback
      -- "rcarriga/nvim-notify",
    },
    config = function()
      local opts = require("custom.configs.noice").opts
      require("noice").setup(opts)
    end,
  },
  {
    "kdheepak/lazygit.nvim",
      cmd = {
      "LazyGit",
      "LazyGitConfig",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
      },
      keys = {
        { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" }
      },
  },
  {
    "shellRaining/hlchunk.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local opts = require("custom.configs.hlchunk").opts
      require("hlchunk").setup(opts)
    end
  },
  {
    "supermaven-inc/supermaven-nvim",
    lazy = false,
    config = function()
      local opts = require("custom.configs.supermaven").opts
      require("supermaven-nvim").setup(opts)
    end,
  },
  -- {
  --   "zbirenbaum/copilot.lua",
  --   lazy = false,
  --   event = "InsertEnter",
  --   cmd = "Copilot",
  --   build = ":Copilot auth",
  --   config = function()
  --     local opts = require("custom.configs.copilot").opts
  --     require("copilot").setup(opts)
  --   end,
  -- },
  {
    "Pocco81/auto-save.nvim",
    lazy = false,
    config = function()
      require("custom.configs.autosave")
    end,
  },
  {
    'wakatime/vim-wakatime',
    lazy = false,
  },
  {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
  },
  keys = {
    { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
    { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
    { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
    { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
    { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
  },
  {
    "kylechui/nvim-surround",
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
        require("nvim-surround").setup({
            -- Configuration here, or leave empty to use defaults
        })
    end
  }
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
