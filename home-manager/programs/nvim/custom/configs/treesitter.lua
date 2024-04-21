local configs = require("plugins.configs.treesitter")

configs.options = {
  ensure_installed = {
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
  },
	autotag = {
		enable = true,
	},
	incremental_selection = {
		enable = true,
	},
	textobjects = {
		enable = true,
	},
	context_commentstring = {
		enable = true,
		enable_autocmd = false,
	},
}

return configs
