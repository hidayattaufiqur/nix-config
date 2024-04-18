vim.keymap.set("i", "<C-b>", "<ESC>^i", { desc = "Move Beginning of line" })
vim.keymap.set("i", "<C-e>", "<End>", { desc = "Move End of line" })
vim.keymap.set("i", "<C-h>", "<Left>", { desc = "Move Left" })
vim.keymap.set("i", "<C-l>", "<Right>", { desc = "Move Right" })
vim.keymap.set("i", "<C-j>", "<Down>", { desc = "Move Down" })
vim.keymap.set("i", "<C-k>", "<Up>", { desc = "Move Up" })

vim.keymap.set("n", "<Esc>", "<cmd>noh<CR>", { desc = "General Clear highlights" })

vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Switch Window left" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Switch Window right" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Switch Window down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Switch Window up" })

vim.keymap.set("n", "<C-s>", "<cmd>w<CR>", { desc = "File Save" })
vim.keymap.set("n", "<C-c>", "<cmd>%y+<CR>", { desc = "File Copy whole" })

vim.keymap.set("n", "<leader>n", "<cmd>set nu!<CR>", { desc = "Toggle Line number" })
vim.keymap.set("n", "<leader>rn", "<cmd>set rnu!<CR>", { desc = "Toggle Relative number" })
vim.keymap.set("n", "<leader>ch", "<cmd>NvCheatsheet<CR>", { desc = "Toggle NvCheatsheet" })

vim.keymap.set("n", "<leader>fm", function()
  require("conform").format { lsp_fallback = true }
end, { desc = "Format Files" })

-- global lsp mappings
vim.keymap.set("n", "<leader>lf", vim.diagnostic.open_float, { desc = "Lsp floating diagnostics" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Lsp prev diagnostic" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Lsp next diagnostic" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Lsp diagnostic loclist" })

-- tabufline
vim.keymap.set("n", "<leader>b", "<cmd>enew<CR>", { desc = "Buffer New" })

vim.keymap.set("n", "<tab>", function()
  require("nvchad.tabufline").next()
end, { desc = "Buffer Goto next" })

vim.keymap.set("n", "<S-tab>", function()
  require("nvchad.tabufline").prev()
end, { desc = "Buffer Goto prev" })

vim.keymap.set("n", "<leader>x", function()
  require("nvchad.tabufline").close_buffer()
end, { desc = "Buffer Close" })

-- Comment
vim.keymap.set("n", "<leader>/", function()
  require("Comment.api").toggle.linewise.current()
end, { desc = "Comment Toggle" })

vim.keymap.set(
  "v",
  "<leader>/",
  "<ESC><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<CR>",
  { desc = "Comment Toggle" }
)

-- nvimtree
vim.keymap.set("n", "<C-n>", "<cmd>NvimTreeToggle<CR>", { desc = "Nvimtree Toggle window" })
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeFocus<CR>", { desc = "Nvimtree Focus window" })

-- telescope
vim.keymap.set("n", "<leader>fw", "<cmd>Telescope live_grep<CR>", { desc = "Telescope Live grep" })
vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Telescope Find buffers" })
vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Telescope Help page" })
vim.keymap.set("n", "<leader>ma", "<cmd>Telescope marks<CR>", { desc = "Telescope Find marks" })
vim.keymap.set("n", "<leader>fo", "<cmd>Telescope oldfiles<CR>", { desc = "Telescope Find oldfiles" })
vim.keymap.set("n", "<leader>fz", "<cmd>Telescope current_buffer_fuzzy_find<CR>", { desc = "Telescope Find in current buffer" })
vim.keymap.set("n", "<leader>cm", "<cmd>Telescope git_commits<CR>", { desc = "Telescope Git commits" })
vim.keymap.set("n", "<leader>gt", "<cmd>Telescope git_status<CR>", { desc = "Telescope Git status" })
vim.keymap.set("n", "<leader>pt", "<cmd>Telescope terms<CR>", { desc = "Telescope Pick hidden term" })
vim.keymap.set("n", "<leader>th", "<cmd>Telescope themes<CR>", { desc = "Telescope Nvchad themes" })
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Telescope Find files" })
vim.keymap.set(
  "n",
  "<leader>fa",
  "<cmd>Telescope find_files follow=true no_ignore=true hidden=true<CR>",
  { desc = "Telescope Find all files" }
)

-- terminal
vim.keymap.set("t", "<C-x>", "<C-\\><C-N>", { desc = "Terminal Escape terminal mode" })

-- new terminals
vim.keymap.set("n", "<leader>h", function()
  require("nvchad.term").new { pos = "sp", size = 0.3 }
end, { desc = "Terminal New horizontal term" })

vim.keymap.set("n", "<leader>v", function()
  require("nvchad.term").new { pos = "vsp", size = 0.3 }
end, { desc = "Terminal New vertical window" })

-- toggleable
vim.keymap.set({ "n", "t" }, "<A-v>", function()
  require("nvchad.term").toggle { pos = "vsp", id = "vtoggleTerm", size = 0.3 }
end, { desc = "Terminal Toggleable vertical term" })

vim.keymap.set({ "n", "t" }, "<A-h>", function()
  require("nvchad.term").toggle { pos = "sp", id = "htoggleTerm", size = 0.3 }
end, { desc = "Terminal New horizontal term" })

vim.keymap.set({ "n", "t" }, "<A-i>", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm" }
end, { desc = "Terminal Toggle Floating term" })

vim.keymap.set("t", "<ESC>", function()
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_close(win, true)
end, { desc = "Terminal Close term in terminal mode" })

-- whichkey
vim.keymap.set("n", "<leader>wK", "<cmd>WhichKey <CR>", { desc = "Whichkey all keymaps" })

vim.keymap.set("n", "<leader>wk", function()
  vim.cmd("WhichKey " .. vim.fn.input "WhichKey: ")
end, { desc = "Whichkey query lookup" })

-- blankline
vim.keymap.set("n", "<leader>cc", function()
  local config = { scope = {} }
  config.scope.exclude = { language = {}, node_type = {} }
  config.scope.include = { node_type = {} }
  local node = require("ibl.scope").get(vim.api.nvim_get_current_buf(), config)

  if node then
    local start_row, _, end_row, _ = node:range()
    if start_row ~= end_row then
      vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { start_row + 1, 0 })
      vim.api.nvim_feedkeys("_", "n", true)
    end
  end
end, { desc = "Blankline Jump to current context" })
