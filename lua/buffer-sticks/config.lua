-- luacheck: globals vim
-- Plugin configuration

---@alias BufferSticksHighlights vim.api.keyset.highlight

---@class BufferSticksOffset
---@field x integer Horizontal offset from default position
---@field y integer Vertical offset from default position

---@class BufferSticksPadding
---@field top integer Top padding inside the window
---@field right integer Right padding inside the window
---@field bottom integer Bottom padding inside the window
---@field left integer Left padding inside the window

---@class BufferSticksListKeys
---@field close_buffer string Key combination to close buffer in list mode
---@field move_up string Key to move selection up in list mode
---@field move_down string Key to move selection down in list mode
---@field confirm string Key to confirm selection in list mode

---@class BufferSticksFilterKeys
---@field enter string Key to enter filter mode
---@field confirm string Key to confirm selection in filter mode
---@field exit string Key to exit filter mode
---@field backspace string Key to delete character in filter mode
---@field move_up string Key to move selection up in filter mode
---@field move_down string Key to move selection down in filter mode

---@class BufferSticksListFilter
---@field title string Title for filter prompt when filter input is not empty
---@field title_empty string Title for filter prompt when filter input is empty
---@field active_indicator string Symbol to show for the selected item in filter mode
---@field fuzzy_cutoff number Cutoff value for fuzzy matching algorithm (default: 100)
---@field keys BufferSticksFilterKeys Key mappings for filter mode

---@class BufferSticksList
---@field show string[] What to show in list mode: "filename", "space", "label", "stick"
---@field active_indicator string Symbol to show for the selected item when using arrow navigation
---@field keys BufferSticksListKeys Key mappings for list mode
---@field filter BufferSticksListFilter Filter configuration

---@class BufferSticksLabel
---@field show "always"|"list"|"never" When to show buffer name characters

---@class BufferSticksFilter
---@field filetypes? string[] List of filetypes to exclude from buffer sticks
---@field buftypes? string[] List of buftypes to exclude from buffer sticks (e.g., "terminal", "help", "quickfix")
---@field names? string[] List of buffer name patterns to exclude (supports lua patterns)

---@class BufferSticksPreviewFloat
---@field position? "left"|"right"|"below" Position of the preview window (default: "right")
---@field width? number Width as fraction of screen (default: 0.5)
---@field height? number Height as fraction of screen (default: 0.8)
---@field border? string Border style (default: "single")
---@field title? string|boolean Title: nil/true = filename, false = none, string = custom
---@field title_pos? "left"|"center"|"right" Title position (default: "center")
---@field footer? string|"filename" Footer: "filename" = filename, string = custom
---@field footer_pos? "left"|"center"|"right" Footer position (default: "center")

---@class BufferSticksPreview
---@field enabled? boolean Whether preview is enabled (default: true)
---@field mode? "float"|"current"|"last_window" Preview mode (default: "float")
---@field float? BufferSticksPreviewFloat Float window configuration

---@class BufferSticksConfig
---@field show_indicators boolean show indicators unless explicitly disabled
---@field offset BufferSticksOffset Position offset for fine-tuning
---@field padding BufferSticksPadding Padding inside the window
---@field border? string Border style (default: "none")
---@field active_char string Character to display for the active buffer
---@field inactive_char string Character to display for inactive buffers
---@field alternate_char string Character to display for the alternate buffer
---@field alternate_modified_char string Character to display for the alternate modified buffer
---@field active_modified_char string Character to display for the active modified buffer
---@field inactive_modified_char string Character to display for inactive modified buffers
---@field position? "right"|"center" List window position (default: "right")
---@field transparent boolean Whether the background should be transparent
---@field winblend? number Window blend level (0-100)
---@field auto_hide boolean Auto-hide when cursor is over float
---@field label? BufferSticksLabel Label display configuration
---@field list? BufferSticksList List mode configuration
---@field filter? BufferSticksFilter Filter configuration for excluding buffers
---@field preview? BufferSticksPreview Preview configuration
---@field highlights table<string, BufferSticksHighlights> Highlight groups for active/inactive/label states
---@field setup fun(opts?: BufferSticksConfig) Apply user configuration

---@type BufferSticksConfig
local M = {
	show_indicators = true,
	offset = { x = 0, y = 0 },
	padding = { top = 0, right = 1, bottom = 0, left = 1 },
	border = "none",
	active_char = "──",
	inactive_char = " ─",
	alternate_char = " ─",
	active_modified_char = "──",
	inactive_modified_char = " ─",
	alternate_modified_char = " ─",
	position = "right",
	transparent = true,
	auto_hide = true,
	label = { show = "list" },
	list = {
		show = { "filename", "space", "label" },
		active_indicator = "•",
		keys = {
			close_buffer = "<C-q>",
			move_up = "<Up>",
			move_down = "<Down>",
			confirm = "<CR>",
		},
		filter = {
			title = "➜ ",
			title_empty = "Filter",
			active_indicator = "•",
			fuzzy_cutoff = 100,
			keys = {
				enter = "/",
				confirm = "<CR>",
				exit = "<Esc>",
				backspace = "<BS>",
				move_up = "<Up>",
				move_down = "<Down>",
			},
		},
	},
	preview = {
		enabled = true,
		mode = "float",
		float = {
			position = "right",
			width = 0.5,
			height = 0.8,
			border = "single",
			title = nil,
			title_pos = "center",
			footer = nil,
			footer_pos = "center",
		},
	},
	highlights = {
		active = { fg = "#bbbbbb" },
		alternate = { fg = "#888888" },
		inactive = { fg = "#333333" },
		active_modified = { fg = "#ffffff" },
		alternate_modified = { fg = "#dddddd" },
		inactive_modified = { fg = "#999999" },
		label = { fg = "#aaaaaa", italic = true },
		filter_selected = { fg = "#bbbbbb", italic = true },
		filter_title = { fg = "#aaaaaa", italic = true },
		list_selected = { fg = "#bbbbbb", italic = true },
	},
}

---Apply user configuration
---@param opts? BufferSticksConfig User configuration options
function M.setup(opts)
	opts = opts or {}
	local merged = vim.tbl_deep_extend("force", M, opts)
	for k, v in pairs(merged) do
		M[k] = v
	end
end

return M
