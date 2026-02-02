-- luacheck: globals vim
-- Preview functionality

local config = require("buffer-sticks.config")
local state = require("buffer-sticks.state")

local M = {}

---Create or update the preview floating window
---@param buffer_id integer Buffer ID to preview
function M.create_float(buffer_id)
	if not vim.api.nvim_buf_is_valid(buffer_id) then
		return
	end

	local preview_config = config.preview and config.preview.float or {}
	local position = preview_config.position or "right"
	local width_frac = preview_config.width or 0.5
	local height_frac = preview_config.height or 0.8

	local editor_width = vim.o.columns
	local editor_height = vim.o.lines

	local width = math.floor(editor_width * width_frac)
	local height = math.floor(editor_height * height_frac)

	local col, row
	if position == "left" then
		col = 0
		row = math.floor((editor_height - height) / 2)
	elseif position == "below" then
		col = math.floor((editor_width - width) / 2)
		row = editor_height - height
	else
		col = editor_width - width - (state.win_pos.width or 0) - 2
		row = math.floor((editor_height - height) / 2)
	end

	local win_config = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = preview_config.border or "single",
		focusable = false,
		zindex = 9,
	}

	if preview_config.title ~= false then
		local title_text
		if type(preview_config.title) == "string" then
			title_text = preview_config.title
		else
			local buf_name = vim.api.nvim_buf_get_name(buffer_id)
			title_text = buf_name ~= "" and vim.fn.fnamemodify(buf_name, ":t") or "[No Name]"
		end
		win_config.title = " " .. title_text .. " "
		win_config.title_pos = preview_config.title_pos or "center"
	end

	if preview_config.footer then
		local title_text = preview_config.footer
		if preview_config.footer == "filename" then
			local buf_name = vim.api.nvim_buf_get_name(buffer_id)
			title_text = buf_name ~= "" and vim.fn.fnamemodify(buf_name, ":t") or "[No Name]"
		end
		win_config.footer = " " .. title_text .. " "
		win_config.footer_pos = preview_config.footer_pos or "center"
	end

	if state.preview_float_win and vim.api.nvim_win_is_valid(state.preview_float_win) then
		vim.api.nvim_win_set_config(state.preview_float_win, win_config)
		pcall(vim.api.nvim_win_set_buf, state.preview_float_win, buffer_id)
	else
		state.preview_float_win = vim.api.nvim_open_win(buffer_id, false, win_config)
	end

   if state.preview_float_win and vim.api.nvim_win_is_valid(state.preview_float_win) then
     vim.wo[state.preview_float_win].signcolumn = "no"
   end
end

---Clean up preview resources
---@param restore_original? boolean Whether to restore original buffer in "current" mode
function M.cleanup(restore_original)
	if restore_original and config.preview and config.preview.mode == "current" then
		if state.preview_origin_buf and vim.api.nvim_buf_is_valid(state.preview_origin_buf) then
			pcall(vim.api.nvim_set_current_buf, state.preview_origin_buf)
		end
	end

	if state.preview_float_win and vim.api.nvim_win_is_valid(state.preview_float_win) then
		pcall(vim.api.nvim_win_close, state.preview_float_win, true)
	end
	state.preview_float_win = nil
	state.preview_float_buf = nil
	state.preview_origin_win = nil
	state.preview_origin_buf = nil
end

---Update preview based on selected buffer
---@param buffer_id integer Buffer ID to preview
function M.update(buffer_id)
	if not config.preview or not config.preview.enabled then
		return
	end

	if not buffer_id or not vim.api.nvim_buf_is_valid(buffer_id) then
		return
	end

	local mode = config.preview.mode

	if mode == "float" then
		M.create_float(buffer_id)
	elseif mode == "current" then
		pcall(vim.api.nvim_set_current_buf, buffer_id)
	elseif mode == "last_window" then
		if state.preview_origin_win and vim.api.nvim_win_is_valid(state.preview_origin_win) then
			local current_win = vim.api.nvim_get_current_win()
			pcall(vim.api.nvim_win_set_buf, state.preview_origin_win, buffer_id)
			if current_win ~= state.preview_origin_win then
				pcall(vim.api.nvim_set_current_win, current_win)
			end
		end
	end
end

return M
