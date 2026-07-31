-- luacheck: globals vim
-- Buffer rendering

local config = require("buffer-sticks.config")
local state = require("buffer-sticks.state")
local buffers_mod = require("buffer-sticks.buffers")
local window = require("buffer-sticks.window")
local fuzzy = require("buffer-sticks.fuzzy")

local M = {}

-- Right-align lines within a given width by padding with spaces
---@param lines string[] Lines to align
---@param width number Target width for alignment
---@return string[] aligned_lines Right-aligned lines
local function right_align_lines(lines, width)
	local aligned_lines = {}
	for _, line in ipairs(lines) do
		local content_width = vim.fn.strwidth(line)
		local padding = width - content_width
		local aligned_line = string.rep(" ", math.max(0, config.padding.left + padding))
			.. line
			.. string.rep(" ", math.max(0, config.padding.right))
		table.insert(aligned_lines, aligned_line)
	end
	return aligned_lines
end

-- Apply vertical padding (top and bottom) to lines
---@param lines string[] Lines to add vertical padding to
---@return string[] padded_lines Lines with top and bottom padding applied
local function vertical_align_lines(lines)
	local padded_lines = {}

	for _ = 1, config.padding.top do
		table.insert(padded_lines, lines[1] and string.rep(" ", vim.fn.strwidth(lines[1])) or "")
	end

	for _, line in ipairs(lines) do
		table.insert(padded_lines, line)
	end

	for _ = 1, config.padding.bottom do
		table.insert(padded_lines, lines[1] and string.rep(" ", vim.fn.strwidth(lines[1])) or "")
	end

	return padded_lines
end

-- Get filename for a buffer
---@param buffer table Buffer info
---@param display_paths table<integer, string> Map of buffer.id to display path
---@return string filename The buffer filename
local function get_buffer_filename(buffer, display_paths)
	return display_paths[buffer.id] or vim.fn.fnamemodify(buffer.name, ":t")
end

-- Get the stick character for a buffer
---@param buffer table Buffer info
---@return string char The stick character
---@return string hl_group The highlight group
local function get_stick_char(buffer)
	local char, hl_group
	if buffer.is_modified then
		if buffer.is_current then
			char = config.active_modified_char
			hl_group = "BufferSticksActiveModified"
		elseif buffer.is_alternate then
			char = config.alternate_modified_char
			hl_group = "BufferSticksAlternateModified"
		else
			char = config.inactive_modified_char
			hl_group = "BufferSticksInactiveModified"
		end
	else
		if buffer.is_current then
			char = config.active_char
			hl_group = "BufferSticksActive"
		elseif buffer.is_alternate then
			char = config.alternate_char
			hl_group = "BufferSticksAlternate"
		else
			char = config.inactive_char
			hl_group = "BufferSticksInactive"
		end
	end
	return char, hl_group
end

-- Get alignment for a specific component
---@param component string Component name ("filename", "label", "stick")
---@return string Alignment direction ("left", "center", "right")
local function get_component_alignment(component)
	local align_config = config.list and config.list.align or {}
	return align_config[component] or "left"
end

-- Calculate column widths for all buffers
---@param buffers table[] List of buffers
---@param display_paths table<integer, string> Map of buffer.id to display path
---@return table column_widths Map of component names to their max widths
local function calculate_column_widths(buffers, display_paths)
	local column_widths = {}

	for _, buffer in ipairs(buffers) do
		-- Calculate filename width
		local filename = get_buffer_filename(buffer, display_paths)
		local filename_width = vim.fn.strwidth(filename)
		column_widths.filename = math.max(column_widths.filename or 0, filename_width)

		-- Calculate label width
		local label_width = vim.fn.strwidth(buffer.label)
		column_widths.label = math.max(column_widths.label or 0, label_width)

		-- Calculate stick width (without calling get_stick_char yet, use fixed width)
		local stick_width = 2 -- Default stick width
		column_widths.stick = math.max(column_widths.stick or 0, stick_width)
	end

	return column_widths
end

-- Align text according to specified alignment
---@param text string Text to align
---@param width number Target width
---@param align string Alignment direction ("left", "center", "right")
---@param separator string Separator to add after aligned text
---@return string Aligned text
local function align_text(text, width, align, separator)
	separator = separator or ""
	local text_width = vim.fn.strwidth(text)

	-- If text width exceeds target width, truncate text
	if text_width > width then
		text = vim.fn.strcharpart(text, 0, width)
		text_width = vim.fn.strwidth(text)
	end

	local result = ""

	if align == "left" then
		-- Left align: text on the left, pad right to specified width
		result = text .. string.rep(" ", width - text_width)
	elseif align == "center" then
		-- Center align: pad equally on both sides
		local padding_needed = width - text_width
		local left_padding = math.floor(padding_needed / 2)
		local right_padding = padding_needed - left_padding
		result = string.rep(" ", left_padding) .. text .. string.rep(" ", right_padding)
	elseif align == "right" then
		-- Right align: pad left, text on the right
		result = string.rep(" ", width - text_width) .. text
	else
		-- Default to left align
		result = text .. string.rep(" ", width - text_width)
	end

	-- Add separator
	result = result .. separator

	return result
end

-- Find the original index of a buffer in the full buffers list
---@param buffer_id number The buffer ID to find
---@param buffers table[] List of buffers to search
---@return number|nil index The original index in the buffers list, or nil if not found
local function find_buffer_index(buffer_id, buffers)
	for i, buf in ipairs(buffers) do
		if buf.id == buffer_id then
			return i
		end
	end
	return nil
end

-- Get the active indicator for filter or list mode
---@param is_filter_mode boolean Whether in filter mode
---@return string indicator The active indicator character
local function get_active_indicator(is_filter_mode)
	if is_filter_mode then
		local fc = config.list and config.list.filter or {}
		return fc.active_indicator or "•"
	else
		local lc = config.list or {}
		return lc.active_indicator or "•"
	end
end

-- Calculate display text for label component
---@param buffer table Buffer info
---@param is_filter_selected boolean Whether buffer is selected in filter mode
---@param is_list_selected boolean Whether buffer is selected in list mode
---@return string label_text The label text to display
local function get_label_text(buffer, is_filter_selected, is_list_selected)
	if is_filter_selected then
		return get_active_indicator(true)
	elseif is_list_selected then
		return get_active_indicator(false)
	else
		return buffer.label
	end
end

-- Precompute common buffer states for rendering
---@param buffer table Buffer info
---@param buffer_idx number Index in filtered_buffers
---@param buffers table[] Full buffers list
---@return table states Precomputed states
local function compute_buffer_states(buffer, buffer_idx, buffers)
	local original_buffer_index = find_buffer_index(buffer.id, buffers)
	local is_filter_selected = state.filter_mode and buffer_idx == state.filter_selected_index
	local is_list_selected = state.list_mode
		and not state.filter_mode
		and original_buffer_index == state.list_mode_selected_index
	local stick_char, stick_hl_group = get_stick_char(buffer)
	local should_show_char = config.label
		and (config.label.show == "always" or (config.label.show == "list" and state.list_mode))

	return {
		original_buffer_index = original_buffer_index,
		is_filter_selected = is_filter_selected,
		is_list_selected = is_list_selected,
		stick_char = stick_char,
		stick_hl_group = stick_hl_group,
		should_show_char = should_show_char,
	}
end

-- Sort buffers based on configured sort option
---@param buffers table[] List of buffers to sort
---@param display_paths table<integer, string> Map of buffer.id to display path
---@return table[] sorted_buffers Sorted buffers
local function sort_buffers(buffers, display_paths)
	local sort_config = config.list and config.list.sort or nil
	if not sort_config then
		return buffers
	end

	local sort_field = sort_config.field or "filename"
	local ascending = sort_config.ascending ~= false -- Default ascending order

	-- Create a copy to avoid modifying the original buffers
	local sorted_buffers = vim.deepcopy(buffers)

	table.sort(sorted_buffers, function(a, b)
		local a_value, b_value
		if sort_field == "id" then
			a_value = a.id
			b_value = b.id
		elseif sort_field == "filename" then
			a_value = get_buffer_filename(a, display_paths)
			b_value = get_buffer_filename(b, display_paths)
		elseif sort_field == "label" then
			a_value = a.label or ""
			b_value = b.label or ""
		else
			--- If the field is not supported, keep the original order
			return false
		end

		if ascending then
			return a_value < b_value
		else
			return a_value > b_value
		end
	end)

	return sorted_buffers
end

-- Apply fuzzy filter to buffers based on current filter input
---@param buffers table[] List of buffers to filter
---@param display_paths table<integer, string> Map of buffer.id to display path
---@return integer[] filtered_indices Indices of matched buffers
function M.apply_fuzzy_filter(buffers, display_paths)
	local candidates = {}
	for _, buffer in ipairs(buffers) do
		local display_name = get_buffer_filename(buffer, display_paths)
		table.insert(candidates, display_name)
	end

	local filter_config = config.list and config.list.filter or {}
	local cutoff = filter_config.fuzzy_cutoff or 100
	local _, filtered_indices = fuzzy.filtersort(state.filter_input, candidates, cutoff)
	return filtered_indices
end

-- Render buffer indicators in the floating window
function M.render()
	local current_tab = vim.api.nvim_get_current_tabpage()
	local win = state.wins[current_tab]

	if not vim.api.nvim_buf_is_valid(state.buf) or not win or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local buffers = buffers_mod.get_buffer_list()
	local lines = {}

	local display_paths = buffers_mod.get_display_paths(buffers)

	local filtered_buffers = buffers
	local filtered_indices = {}
	if state.filter_mode and state.filter_input ~= "" then
		filtered_indices = M.apply_fuzzy_filter(buffers, display_paths)
		filtered_buffers = {}
		for _, idx in ipairs(filtered_indices) do
			table.insert(filtered_buffers, buffers[idx])
		end
	else
		for i = 1, #buffers do
			table.insert(filtered_indices, i)
		end
	end

	-- Sort after applying filter
	filtered_buffers = sort_buffers(filtered_buffers, display_paths)

	local has_two_char = buffers_mod.has_two_char_label(filtered_buffers)

	-- Calculate maximum column widths for alignment
	local column_widths = calculate_column_widths(filtered_buffers, display_paths)

	if state.filter_mode then
		local filter_config = config.list and config.list.filter or {}
		local filter_title = #state.filter_input > 0 and (filter_config.title or "Filter: ")
			or (filter_config.title_empty or "Filter:   ")
		local padding = has_two_char and "   " or "  "
		local filter_prompt = filter_title .. state.filter_input .. padding
		table.insert(lines, filter_prompt)
	end

	local buffer_states = {}
	for buffer_idx, buffer in ipairs(filtered_buffers) do
		buffer_states[buffer_idx] = compute_buffer_states(buffer, buffer_idx, buffers)
	end

	for buffer_idx, buffer in ipairs(filtered_buffers) do
		local line_content
		local states = buffer_states[buffer_idx]
		local is_filter_selected = states.is_filter_selected
		local is_list_selected = states.is_list_selected
		local stick_char = states.stick_char
		local should_show_char = states.should_show_char

		if state.list_mode and config.list and config.list.show then
			-- Build display content in order of config.list.show, using column alignment
			local aligned_parts = {}
			local separator_value = config.list.separator or "  "

			-- Iterate through show list order to build parts
			for i, component in ipairs(config.list.show) do
				local is_last_component = (i == #config.list.show)
				local separator = is_last_component and "" or separator_value

				if component == "stick" then
					local stick_width = column_widths.stick or 2
					local alignment = get_component_alignment("stick")

					local aligned_stick = align_text(stick_char, stick_width, alignment, separator)
					table.insert(aligned_parts, aligned_stick)
				elseif component == "filename" then
					local filename = get_buffer_filename(buffer, display_paths)
					local filename_width = column_widths.filename or 10
					local alignment = get_component_alignment("filename")
					local aligned_filename = align_text(filename, filename_width, alignment, separator)
					table.insert(aligned_parts, aligned_filename)
				elseif component == "label" then
					local label_text = get_label_text(buffer, is_filter_selected, is_list_selected)
					local label_width = column_widths.label or 2
					local alignment = get_component_alignment("label")
					local aligned_label = align_text(label_text, label_width, alignment, separator)
					table.insert(aligned_parts, aligned_label)
				end
			end

			if #aligned_parts > 0 then
				line_content = table.concat(aligned_parts, "") -- No additional spaces, spacing is handled in alignment
			else
				line_content = ""
			end
		elseif should_show_char then
			line_content = stick_char .. " " .. buffer.label
		else
			line_content = stick_char
		end
		table.insert(lines, line_content)
	end

	local window_width = window.calculate_required_width()
	local aligned_lines = right_align_lines(lines, window_width)
	local final_lines = vertical_align_lines(aligned_lines)

	local ns_id = vim.api.nvim_create_namespace("BufferSticks")
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, final_lines)

	if state.filter_mode then
		local filter_line_idx = config.padding.top
		vim.hl.range(state.buf, ns_id, "BufferSticksFilterTitle", { filter_line_idx, 0 }, { filter_line_idx, -1 })
	end

	local line_offset = state.filter_mode and 1 or 0
	for i, buffer in ipairs(filtered_buffers) do
		local line_idx = i - 1 + config.padding.top + line_offset
		local line_content = final_lines[i + config.padding.top + line_offset]

		-- Use precomputed states
		local states = buffer_states[i]
		local is_filter_selected = states.is_filter_selected
		local is_list_selected = states.is_list_selected
		local stick_hl_group = states.stick_hl_group

		if state.list_mode and config.list and config.list.show then
			-- Recalculate component positions based on config.list.show order using column widths

			local components_positions = {}
			local col_offset = 0
			local padding_match = line_content:match("^( *)")
			if padding_match then
				col_offset = #padding_match
			end

			-- Record start position of each component

			local component_start = col_offset
			for _, component in ipairs(config.list.show) do
				if component == "stick" then
					local stick_width = column_widths.stick or 2
					components_positions["stick"] = {
						start = component_start,
						width = stick_width,
					}
					component_start = component_start + stick_width
				-- No longer checking for spaces as they have been removed
				elseif component == "filename" then
					local filename_width = column_widths.filename or 10
					components_positions["filename"] = {
						start = component_start,
						width = filename_width,
					}
					component_start = component_start + filename_width
				elseif component == "label" then
					local label_width = column_widths.label or 2
					components_positions["label"] = {
						start = component_start,
						width = label_width,
					}
					component_start = component_start + label_width
				end
			end

			-- Apply highlighting to each component

			for component_type, pos_info in pairs(components_positions) do
				if component_type == "stick" or component_type == "filename" then
					local hl_group = is_filter_selected and "BufferSticksFilterSelected"
						or is_list_selected and "BufferSticksListSelected"
						or stick_hl_group
					vim.hl.range(
						state.buf,
						ns_id,
						hl_group,
						{ line_idx, pos_info.start },
						{ line_idx, pos_info.start + pos_info.width }
					)
				elseif component_type == "label" then
					if is_filter_selected or is_list_selected then
						local hl_group = is_filter_selected and "BufferSticksFilterSelected"
							or "BufferSticksListSelected"
						local indicator = get_active_indicator(is_filter_selected)
						local content_start = line_content:sub(pos_info.start + 1)
						local indicator_start_pos = content_start:find(vim.pesc(indicator))
						if indicator_start_pos then
							local byte_start = pos_info.start + indicator_start_pos - 1
							local byte_end = byte_start + #indicator
							vim.hl.range(state.buf, ns_id, hl_group, { line_idx, byte_start }, { line_idx, byte_end })
						end
					else
						local content_start = line_content:sub(pos_info.start + 1)
						local label_start_pos = content_start:find(vim.pesc(buffer.label))

						if label_start_pos then
							local byte_start = pos_info.start + label_start_pos - 1
							local byte_end = byte_start + #buffer.label
							vim.hl.range(
								state.buf,
								ns_id,
								"BufferSticksLabel",
								{ line_idx, byte_start },
								{ line_idx, byte_end }
							)
						end
					end
				end
			end
		else
			local hl_group = is_filter_selected and "BufferSticksFilterSelected"
				or is_list_selected and "BufferSticksListSelected"
				or stick_hl_group
			vim.hl.range(state.buf, ns_id, hl_group, { line_idx, 0 }, { line_idx, -1 })
		end
	end
end

return M
