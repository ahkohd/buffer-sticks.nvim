-- luacheck: globals vim
-- List mode input handling

local config = require("buffer-sticks.config")
local state = require("buffer-sticks.state")
local buffers_mod = require("buffer-sticks.buffers")
local window = require("buffer-sticks.window")
local render = require("buffer-sticks.render")
local preview = require("buffer-sticks.preview")

local M = {}

---Return true when captured input matches configured keycode
---@param char number|string
---@param char_str string
---@param key string
---@return boolean
local function matches_key(char, char_str, key)
	if type(key) ~= "string" or key == "" then
		return false
	end

	-- expand key param to internal representation
	local termcode = vim.api.nvim_replace_termcodes(key, true, false, true)

	if type(char_str) == "string" and char_str == termcode then
		return true
	end

	if type(char) == "number" then
		local ok, tc_nr = pcall(vim.fn.char2nr, termcode)
		if ok and tc_nr == char then
			return true
		end
	end

	return false
end

---Helper to update display with window resize and redraw
local function update_display()
	window.create_or_update()
	render.render()
	vim.cmd("redraw")
end

---Helper to exit list mode
---@param restore_original? boolean Whether to restore original buffer
local function leave(restore_original)
	state.list_mode = false
	state.list_input = ""
	state.list_mode_selected_index = nil
	state.filter_mode = false
	state.filter_input = ""
	state.filter_selected_index = 1
	preview.cleanup(restore_original)
	window.create_or_update()
	render.render()
end

---Handle input in filter mode
---@param char number|string Character input
---@param char_str string String representation
---@param handle_input function Continuation function
---@return boolean handled Whether the input was handled
local function handle_filter_input(char, char_str, handle_input)
	local filter_keys = config.list and config.list.filter and config.list.filter.keys or {}

	-- Move up in filtered list
	if matches_key(char, char_str, filter_keys.move_up) then
		local buffers = buffers_mod.get_buffer_list()
		local display_paths = buffers_mod.get_display_paths(buffers)
		local filtered_indices = render.apply_fuzzy_filter(buffers, display_paths)
		local num_results = #filtered_indices

		if num_results > 0 then
			state.filter_selected_index = state.filter_selected_index - 1
			if state.filter_selected_index < 1 then
				state.filter_selected_index = num_results
			end
			local selected_buffer = buffers[filtered_indices[state.filter_selected_index]]
			if selected_buffer then
				preview.update(selected_buffer.id)
			end
			update_display()
		end
		vim.schedule(handle_input)
		return true
	end

	-- Move down in filtered list
	if matches_key(char, char_str, filter_keys.move_down) then
		local buffers = buffers_mod.get_buffer_list()
		local display_paths = buffers_mod.get_display_paths(buffers)
		local filtered_indices = render.apply_fuzzy_filter(buffers, display_paths)
		local num_results = #filtered_indices

		if num_results > 0 then
			state.filter_selected_index = state.filter_selected_index + 1
			if state.filter_selected_index > num_results then
				state.filter_selected_index = 1
			end
			local selected_buffer = buffers[filtered_indices[state.filter_selected_index]]
			if selected_buffer then
				preview.update(selected_buffer.id)
			end
			update_display()
		end
		vim.schedule(handle_input)
		return true
	end

	-- Enter/confirm
	if matches_key(char, char_str, filter_keys.confirm) then
		local buffers = buffers_mod.get_buffer_list()
		local display_paths = buffers_mod.get_display_paths(buffers)
		local filtered_indices = render.apply_fuzzy_filter(buffers, display_paths)

		if #filtered_indices > 0 then
			local selected_buffer = buffers[filtered_indices[state.filter_selected_index]]
			if selected_buffer then
				if type(state.list_action) == "function" then
					state.list_action(selected_buffer, function()
						leave(false)
					end)
				elseif state.list_action == "open" then
					vim.api.nvim_set_current_buf(selected_buffer.id)
					leave(false)
				elseif state.list_action == "close" then
					vim.api.nvim_buf_delete(selected_buffer.id, { force = false })
					leave(false)
				end
			end
		end
		return true
	end

	-- Backspace
	local backspace_key = filter_keys.backspace or "<BS>"
	if matches_key(char, char_str, backspace_key) then
		if #state.filter_input > 0 then
			state.filter_input = state.filter_input:sub(1, -2)
			state.filter_selected_index = 1
			local buffers = buffers_mod.get_buffer_list()
			local display_paths = buffers_mod.get_display_paths(buffers)
			local filtered_indices = render.apply_fuzzy_filter(buffers, display_paths)
			if #filtered_indices > 0 then
				local selected_buffer = buffers[filtered_indices[state.filter_selected_index]]
				if selected_buffer then
					preview.update(selected_buffer.id)
				end
			end
			update_display()
		end
		vim.schedule(handle_input)
		return true
	end

	-- Regular character input
	if type(char_str) == "string" and #char_str > 0 and type(char) == "number" and char >= 32 and char < 127 then
		if char_str:match("[%w%s%p]") then
			state.filter_input = state.filter_input .. char_str
			state.filter_selected_index = 1
			local buffers = buffers_mod.get_buffer_list()
			local display_paths = buffers_mod.get_display_paths(buffers)
			local filtered_indices = render.apply_fuzzy_filter(buffers, display_paths)
			if #filtered_indices > 0 then
				local selected_buffer = buffers[filtered_indices[state.filter_selected_index]]
				if selected_buffer then
					preview.update(selected_buffer.id)
				end
			end
			update_display()
			vim.schedule(handle_input)
			return true
		end
	end

	vim.schedule(handle_input)
	return true
end

---Enter list mode to navigate or close buffers by typing characters
---@param opts? {action?: "open"|"close"|function} Options for list mode
---@param show_fn function Function to show the buffer sticks
function M.enter(opts, show_fn)
	opts = opts or {}
	local action = opts.action or "open"

	if not state.visible then
		show_fn()
	end

	state.list_mode = true
	state.list_input = ""
	state.list_action = action
	state.list_mode_selected_index = nil
	state.preview_origin_win = vim.api.nvim_get_current_win()
	state.preview_origin_buf = vim.api.nvim_get_current_buf()

	local current_buf = vim.api.nvim_get_current_buf()
	local buffers = buffers_mod.get_buffer_list()
	for idx, buffer in ipairs(buffers) do
		if buffer.id == current_buf then
			state.list_mode_selected_index = idx
			state.last_selected_buffer_id = current_buf
			break
		end
	end

	window.create_or_update()
	render.render()

	if state.list_mode_selected_index then
		preview.update(buffers[state.list_mode_selected_index].id)
	end

	local function handle_input()
		local char = vim.fn.getchar()
		local char_str

		if type(char) == "number" then
			char_str = vim.fn.nr2char(char)
		elseif type(char) == "string" then
			char_str = char
		else
			char_str = ""
		end

		-- Escape or ctrl-c
		local exit_key = config.list and config.list.filter and config.list.filter.keys and config.list.filter.keys.exit or "<Esc>"
		if matches_key(char, char_str, exit_key) or matches_key(char, char_str, "<C-c>") then
			if state.filter_mode then
				state.filter_mode = false
				state.filter_input = ""
				state.filter_selected_index = 1
				update_display()
				vim.schedule(handle_input)
			else
				leave(true)
			end
			return
		end

		-- Filter mode input
		if state.filter_mode then
			handle_filter_input(char, char_str, handle_input)
			return
		end

		-- Arrow keys in list mode
		local list_keys = config.list and config.list.keys or {}

		-- Move up in list
		if matches_key(char, char_str, list_keys.move_up) then
			local buf_list = buffers_mod.get_buffer_list()
			if #buf_list > 0 then
				if state.list_mode_selected_index == nil then
					local cur_buf = vim.api.nvim_get_current_buf()
					for idx, buffer in ipairs(buf_list) do
						if buffer.id == cur_buf then
							state.list_mode_selected_index = idx
							break
						end
					end
					if state.list_mode_selected_index == nil then
						state.list_mode_selected_index = #buf_list
					end
				end
				state.list_mode_selected_index = state.list_mode_selected_index == 1 and #buf_list
					or state.list_mode_selected_index - 1
				state.last_selected_buffer_id = buf_list[state.list_mode_selected_index].id
				preview.update(buf_list[state.list_mode_selected_index].id)
				update_display()
			end
			vim.schedule(handle_input)
			return
		end

		-- Move down in list
		if matches_key(char, char_str, list_keys.move_down) then
			local buf_list = buffers_mod.get_buffer_list()
			if #buf_list > 0 then
				if state.list_mode_selected_index == nil then
					local cur_buf = vim.api.nvim_get_current_buf()
					for idx, buffer in ipairs(buf_list) do
						if buffer.id == cur_buf then
							state.list_mode_selected_index = idx
							break
						end
					end
					if state.list_mode_selected_index == nil then
						state.list_mode_selected_index = 1
					end
				end
				state.list_mode_selected_index = (state.list_mode_selected_index % #buf_list) + 1
				state.last_selected_buffer_id = buf_list[state.list_mode_selected_index].id
				preview.update(buf_list[state.list_mode_selected_index].id)
				update_display()
			end
			vim.schedule(handle_input)
			return
		end

		-- Enter to confirm selection
		local confirm_key = list_keys.confirm or "<CR>"
		if matches_key(char, char_str, confirm_key) and state.list_mode_selected_index ~= nil then
			local buf_list = buffers_mod.get_buffer_list()
			if state.list_mode_selected_index > 0 and state.list_mode_selected_index <= #buf_list then
				local selected_buffer = buf_list[state.list_mode_selected_index]
				if selected_buffer then
					if type(state.list_action) == "function" then
						state.list_action(selected_buffer, function()
							leave(false)
						end)
					elseif state.list_action == "open" then
						vim.api.nvim_set_current_buf(selected_buffer.id)
						leave(false)
					elseif state.list_action == "close" then
						vim.api.nvim_buf_delete(selected_buffer.id, { force = false })
						leave(false)
					end
				end
			end
			return
		end

		-- Enter filter mode
		local filter_keys = config.list and config.list.filter and config.list.filter.keys or {}
		if matches_key(char, char_str, filter_keys.enter) then
			state.filter_mode = true
			state.filter_input = ""
			state.filter_selected_index = 1
			update_display()
			vim.schedule(handle_input)
			return
		end

		-- Close buffer key (ctrl-q)
		local close_key = list_keys.close_buffer or "<C-q>"
		if matches_key(char, char_str, close_key) then
			local cur_buf = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_delete(cur_buf, { force = false })
			leave(false)
			return
		end

		-- Regular character input (label matching)
		if type(char_str) == "string" and #char_str > 0 and char_str:match("%w") then
			state.list_mode_selected_index = nil
			state.list_input = state.list_input .. char_str:lower()

			local buf_list = buffers_mod.get_buffer_list()
			local matches = {}
			for _, buffer in ipairs(buf_list) do
				local label_prefix = buffer.label:sub(1, #state.list_input)
				if label_prefix == state.list_input then
					table.insert(matches, buffer)
				end
			end

			if #matches == 1 then
				if type(state.list_action) == "function" then
					state.list_action(matches[1], function()
						leave(false)
					end)
				elseif state.list_action == "open" then
					vim.api.nvim_set_current_buf(matches[1].id)
					leave(false)
				elseif state.list_action == "close" then
					vim.api.nvim_buf_delete(matches[1].id, { force = false })
					leave(false)
				end
				return
			elseif #matches == 0 then
				leave(true)
				return
			end

			render.render()
			vim.schedule(handle_input)
		else
			leave(true)
		end
	end

	vim.defer_fn(handle_input, 10)
end

return M
