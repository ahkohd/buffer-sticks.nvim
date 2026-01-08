-- luacheck: globals vim
-- Floating window management

local config = require("buffer-sticks.config")
local state = require("buffer-sticks.state")
local buffers_mod = require("buffer-sticks.buffers")

local M = {}

---Calculate the required width based on current display mode and content
---@return number width The calculated width needed for the floating window
function M.calculate_required_width()
	local buffers = buffers_mod.get_buffer_list()
	local max_width

	if state.list_mode and config.list and config.list.show then
		local show_filename = vim.list_contains(config.list.show, "filename")
		local show_space = vim.list_contains(config.list.show, "space")
		local show_label = vim.list_contains(config.list.show, "label")
		local show_stick = vim.list_contains(config.list.show, "stick")

		local total_width = 0

		if show_stick then
			total_width = total_width
				+ math.max(
					vim.fn.strwidth(config.active_char),
					vim.fn.strwidth(config.inactive_char),
					vim.fn.strwidth(config.alternate_char),
					vim.fn.strwidth(config.alternate_modified_char),
					vim.fn.strwidth(config.active_modified_char),
					vim.fn.strwidth(config.inactive_modified_char)
				)
		end

		if show_filename then
			local display_paths = buffers_mod.get_display_paths(buffers)
			local max_filename_width = 0
			for _, buffer in ipairs(buffers) do
				local display_path = display_paths[buffer.id] or vim.fn.fnamemodify(buffer.name, ":t")
				max_filename_width = math.max(max_filename_width, vim.fn.strwidth(display_path))
			end
			total_width = total_width + max_filename_width
		end

		if show_space and (show_stick or show_filename or show_label) then
			local element_count = 0
			if show_stick then
				element_count = element_count + 1
			end
			if show_filename then
				element_count = element_count + 1
			end
			if show_label then
				element_count = element_count + 1
			end
			if element_count > 1 then
				total_width = total_width + (element_count - 1)
			end
		end

		if show_label then
			local max_label_width = 0
			for _, buffer in ipairs(buffers) do
				max_label_width = math.max(max_label_width, vim.fn.strwidth(buffer.label))
			end
			total_width = total_width + max_label_width
		end

		max_width = total_width

		if state.filter_mode then
			local filter_config = config.list and config.list.filter or {}
			local filter_title = #state.filter_input > 0 and (filter_config.title or "Filter: ")
				or (filter_config.title_empty or "Filter:   ")
			local padding = buffers_mod.has_two_char_label(buffers) and "   " or "  "
			local filter_prompt_width = vim.fn.strwidth(filter_title .. state.filter_input .. padding)
			max_width = math.max(max_width, filter_prompt_width)
		end
	else
		local should_show_labels = (config.label and config.label.show == "always")

		max_width = math.max(
			vim.fn.strwidth(config.active_char),
			vim.fn.strwidth(config.inactive_char),
			vim.fn.strwidth(config.alternate_char),
			vim.fn.strwidth(config.alternate_modified_char),
			vim.fn.strwidth(config.active_modified_char),
			vim.fn.strwidth(config.inactive_modified_char)
		)

		if should_show_labels then
			local max_label_width = 0
			for _, buffer in ipairs(buffers) do
				max_label_width = math.max(max_label_width, vim.fn.strwidth(buffer.label))
			end
			max_width = max_width + 1 + max_label_width
		end
	end

	return max_width
end

---Check if cursor position is within the floating window bounds
---@return boolean collision True if cursor is within the window area
function M.check_cursor_collision()
	if not config.auto_hide then
		return false
	end

	if state.win_pos.width == 0 or state.win_pos.height == 0 then
		return false
	end

	local cursor_row = vim.fn.screenrow() - 1
	local cursor_col = vim.fn.screencol() - 1
	local offset = 1

	return cursor_col >= state.win_pos.col - offset
		and cursor_col < state.win_pos.col + state.win_pos.width + offset
		and cursor_row >= state.win_pos.row - offset
		and cursor_row < state.win_pos.row + state.win_pos.height + offset
end

---Create or update the floating window for buffer sticks
---@return table window_info Information about the window and buffer
function M.create_or_update()
	local buffers = buffers_mod.get_buffer_list()
	local content_height = math.max(#buffers, 1)
	local content_width = M.calculate_required_width()

	if state.filter_mode then
		content_height = content_height + 1
	end

	local height = content_height + config.padding.top + config.padding.bottom
	local width = content_width + config.padding.left + config.padding.right

	local position = config.position or "right"
	local row = math.floor((vim.o.lines - height) / 2) + config.offset.y
	local col

	if position == "center" then
		col = math.floor((vim.o.columns - width) / 2) + config.offset.x
	else
		col = vim.o.columns - width - config.offset.x
	end

	if not vim.api.nvim_buf_is_valid(state.buf) then
		state.buf = vim.api.nvim_create_buf(false, true)
		vim.bo[state.buf].bufhidden = "wipe"
		vim.bo[state.buf].filetype = "buffersticks"
	end

	local win_config = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = config.border or "none",
		focusable = false,
		zindex = 10,
	}

	local current_tab = vim.api.nvim_get_current_tabpage()
	local win = state.wins[current_tab]

	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_set_config(win, win_config)
	else
		win = vim.api.nvim_open_win(state.buf, false, win_config)
		state.wins[current_tab] = win
	end

	state.win_pos = { col = col, row = row, width = width, height = height }

	if config.winblend then
		vim.api.nvim_set_option_value("winblend", config.winblend, { win = win })
	end

	if not config.winblend and not config.transparent then
		vim.api.nvim_set_option_value("winhl", "Normal:BufferSticksBackground", { win = win })
	else
		vim.api.nvim_set_option_value("winhl", "Normal:NONE", { win = win })
	end

	return { buf = state.buf, win = win }
end

---Close all windows in all tabs
function M.close_all()
	for _, win in pairs(state.wins) do
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end
	state.wins = {}
end

return M
