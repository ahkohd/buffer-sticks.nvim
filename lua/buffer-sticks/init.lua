-- luacheck: globals vim
-- Buffer Sticks - Visual buffer indicators for Neovim

local config = require("buffer-sticks.config")
local state = require("buffer-sticks.state")
local window = require("buffer-sticks.window")
local render = require("buffer-sticks.render")
local highlights = require("buffer-sticks.highlights")
local list_mode = require("buffer-sticks.list")

---@class BufferSticks
---@field setup function Setup the buffer sticks plugin
---@field toggle function Toggle the visibility of buffer sticks
---@field show function Show the buffer sticks
---@field hide function Hide the buffer sticks
---@field list function Enter list mode
---@field jump function Alias for list mode with open action
---@field close function Alias for list mode with close action
---@field is_visible function Check if buffer sticks are visible
local M = {}

---Handle cursor movement for auto-hide behavior
local function handle_cursor_move()
	if not config.auto_hide or state.list_mode then
		return
	end

	if not state.visible and not state.auto_hidden then
		return
	end

	local collision = window.check_cursor_collision()

	if collision and state.visible and not state.auto_hidden then
		state.auto_hidden = true
		local current_tab = vim.api.nvim_get_current_tabpage()
		local win = state.wins[current_tab]
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_hide(win)
		end
	elseif not collision and state.auto_hidden then
		state.auto_hidden = false
		M.show()
	end
end

---Show the buffer sticks floating window
function M.show()
	if not config.show_indicators and not state.list_mode then
		state.visible = false
		return
	end
	vim.schedule(function()
		if not state.visible then
			return
		end
		window.create_or_update()
		render.render()
		state.auto_hidden = false
	end)
	state.visible = true
end

---Hide the buffer sticks floating window
function M.hide()
	state.visible = false
	state.auto_hidden = false
	window.close_all()
end

---Enter list mode to navigate or close buffers
---@param opts? {action?: "open"|"close"|function} Options for list mode
function M.list(opts)
	list_mode.enter(opts, M.show)
end

---Alias for list mode with "open" action
function M.jump()
	M.list({ action = "open" })
end

---Alias for list mode with "close" action
function M.close()
	M.list({ action = "close" })
end

---Toggle the visibility of buffer sticks
function M.toggle()
	if state.visible then
		M.hide()
	else
		M.show()
	end
end

---Check if the buffer list is visible
---@return boolean Whether the buffer list is visible
function M.is_visible()
	return state.visible
end

---Setup the buffer sticks plugin with user configuration
---@param opts? table User configuration options to override defaults
function M.setup(opts)
	config.setup(opts)
	highlights.setup()

	local augroup = vim.api.nvim_create_augroup("BufferSticks", { clear = true })

	vim.api.nvim_create_autocmd({ "BufEnter", "BufDelete", "BufWipeout" }, {
		group = augroup,
		callback = function(args)
			state.invalidate_cache()

			if (args.event == "BufDelete" or args.event == "BufWipeout") and state.last_selected_buffer_id == args.buf then
				state.last_selected_buffer_id = nil
			end

			if state.visible then
				M.show()
			end
		end,
	})

	vim.api.nvim_create_autocmd({ "BufModifiedSet", "TextChanged", "TextChangedI", "BufWritePost" }, {
		group = augroup,
		callback = function()
			vim.schedule(function()
				if state.visible then
					render.render()
				end
			end)
		end,
	})

	vim.api.nvim_create_autocmd("ColorScheme", {
		group = augroup,
		callback = function()
			vim.schedule(highlights.setup)
		end,
	})

	vim.api.nvim_create_autocmd("VimResized", {
		group = augroup,
		callback = function()
			if state.visible then
				M.show()
			end
		end,
	})

	vim.api.nvim_create_autocmd("TabEnter", {
		group = augroup,
		callback = function()
			if state.visible then
				M.show()
			end
		end,
	})

	vim.api.nvim_create_autocmd({
		"CursorMoved",
		"CursorMovedI",
		"CursorHold",
		"CursorHoldI",
		"WinScrolled",
		"ModeChanged",
		"SafeState",
	}, {
		group = augroup,
		callback = function()
			if config.auto_hide then
				handle_cursor_move()
			end
		end,
	})

	_G.BufferSticks = {
		toggle = M.toggle,
		show = M.show,
		hide = M.hide,
		is_visible = M.is_visible,
		list = M.list,
		jump = M.jump,
		close = M.close,
	}
end

return M
