local M = {}

M.opts = {
  panel = {
    enabled = true,
    auto_refresh = true,
    keymap = {
      jump_prev = "[[",
      jump_next = "]]",
      accept = "<CR>",
      refresh = "gr",
      open = "<M-CR>",
    },
    layout = {
      position = "bottom", -- | top | left | right
      ratio = 0.4,
    },
  },
  suggestion = {
    enabled = false,
    auto_trigger = true,
    debounce = 75,
    keymap = {
      accept = "<C-Space>",
      accept_word = "<C-Right>",
      accept_line = "<C-End>",
      next = "<M-]>",
      prev = "<M-[>",
      dismiss = "<C-[>",
    },
  },
  filetypes = {
    yaml = true,
    markdown = true,
    help = false,
    gitcommit = true,
    gitrebase = true,
    hgcommit = false,
    svn = false,
    cvs = false,
    ["."] = true,
  },
}

return M
