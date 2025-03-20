-- autosave
require("auto-save").setup({
	enabled = true,
	trigger_events = { "InsertLeave", "TextChanged" },
	conditions = {
		exists = true,
		filename_is_not = {},
		filetype_is_not = {},
		modifiable = true,
	},
	write_all_buffers = false,
	debounce_delay = 135,
})
