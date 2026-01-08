<div align="center">

# buffer-sticks.nvim

Elegant buffer indicator and picker.

[![Neovim](https://img.shields.io/badge/Neovim%200.10+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)


<!-- Demo source: https://github.com/user-attachments/assets/8f2b4abe-07c1-4d52-9a58-ea1fa4c13bb1 -->
https://github.com/user-attachments/assets/8f2b4abe-07c1-4d52-9a58-ea1fa4c13bb1

</div>

## Features

- Visual representation of open buffers
- Highlights for active, alternate, inactive, and modified buffers
- List mode for quick buffer navigation or closing by typing characters
- Filter mode with fuzzy search for finding buffers quickly
- Buffer preview while navigating with configurable display modes
- Custom action functions for building buffer pickers
- Configurable positioning and appearance
- Transparent background support
- Persists highlight configuration across colorscheme changes

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "ahkohd/buffer-sticks.nvim",
  config = function()
    require("buffer-sticks").setup()
  end,
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "ahkohd/buffer-sticks.nvim",
  config = function()
    require("buffer-sticks").setup()
  end
}
```

### Quick Setup

```lua
return {
	"ahkohd/buffer-sticks.nvim",
	event = "VeryLazy",
	keys = {
		{
			"<leader>j",
			function()
				BufferSticks.jump()
			end,
			desc = "Jump to buffer",
		},
		{
			"<leader>q",
			function()
				BufferSticks.close()
			end,
			desc = "Close buffer",
		},
		{
			"<leader>p",
			function()
				BufferSticks.list({
					action = function(buffer, leave)
						print("Selected: " .. buffer.name)
						leave()
					end
				})
			end,
			desc = "Buffer picker",
		},
	},
	config = function()
		local sticks = require("buffer-sticks")
		sticks.setup({
			filter = { buftypes = { "terminal" } },
			highlights = {
                active = { link = "Statement" },
                alternate = { link = "StorageClass" },
                inactive = { link = "Whitespace" },
                active_modified = { link = "Constant" },
                alternate_modified = { link = "Constant" },
                inactive_modified = { link = "Constant" },
                label = { link = "Comment" },
                filter_selected = { link = "Statement" },
                filter_title = { link = "Comment" },
                list_selected = { link = "Statement" },
			},
		})
		sticks.show()
	end,
}
```

## Configuration

```lua
require("buffer-sticks").setup({
  show_indicators = true,       -- whether to show stick indicators
  offset = { x = 0, y = 0 },    -- Position offset (positive moves inward from right edge)
  padding = { top = 0, right = 1, bottom = 0, left = 1 }, -- Padding inside the float
  border = "none",             -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
  active_char = "──",           -- Character for active buffer
  inactive_char = " ─",         -- Character for inactive buffers
  alternate_char = " ─",        -- Character for alternate buffer
  active_modified_char = "──",  -- Character for active modified buffer (unsaved changes)
  inactive_modified_char = " ─", -- Character for inactive modified buffers (unsaved changes)
  alternate_modified_char = " ─", -- Character for alternate modified buffer (unsaved changes)
  transparent = true,           -- Remove background color (shows terminal/editor background)
  auto_hide = true,                -- Auto-hide when cursor is over float (default: true)
  label = { show = "list" },       -- Label display: "always", "list", or "never"
  list = {
    show = { "filename", "space", "label" }, -- List mode display options
    active_indicator = "•",       -- Symbol for selected item in list mode (arrow navigation)
    keys = {
      close_buffer = "<C-q>",      -- Key to close buffer in list mode
      move_up = "<Up>",           -- Key to move selection up in list mode
      move_down = "<Down>",       -- Key to move selection down in list mode
    },
    filter = {
      title = "➜ ",                -- Filter prompt title when input is not empty
      title_empty = "Filter",       -- Filter prompt title when input is empty
      active_indicator = "•",       -- Symbol for selected item in filter mode
      fuzzy_cutoff = 100,           -- Cutoff value for fuzzy matching algorithm (default: 100)
      keys = {
        enter = "/",                -- Key to enter filter mode
        confirm = "<CR>",           -- Key to confirm selection
        exit = "<Esc>",             -- Key to exit filter mode
        move_up = "<Up>",           -- Key to move selection up
        move_down = "<Down>",       -- Key to move selection down
      },
    },
  },
  preview = {
    enabled = true,                    -- Enable buffer preview during navigation
    mode = "float",                    -- Preview mode: "float", "current", or "last_window"
    float = {
      position = "right",              -- Float position: "right", "left", or "below"
      width = 0.5,                     -- Width as fraction of screen (0.0 to 1.0)
      height = 0.8,                    -- Height as fraction of screen (0.0 to 1.0)
      border = "single",               -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
      title = nil,                     -- Window title: nil/true = filename, false = no title, "string" = custom (default: nil/filename)
      title_pos = "center",            -- Title position: "left", "center", "right"
      footer = nil,                    -- Window footer (string or nil)
      footer_pos = "center",           -- Footer position: "left", "center", "right"
    },
  },
  -- winblend = 100,                    -- Window blend level (0-100, 0=opaque, 100=fully blended)
  -- filter = {
  --   filetypes = { "help", "qf" },    -- Exclude by filetype (also: "NvimTree", "neo-tree", "Trouble")
  --   buftypes = { "terminal" },       -- Exclude by buftype (also: "help", "quickfix", "nofile")
  --   names = { ".*%.git/.*", "^/tmp/.*" },  -- Exclude buffers matching lua patterns
  -- },
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
  }
})
```

## Usage

```lua
-- Toggle visibility
BufferSticks.toggle()

-- Show
BufferSticks.show()

-- Hide
BufferSticks.hide()

-- Enter list mode to navigate buffers
BufferSticks.list({ action = "open" })

-- Enter list mode to close buffers
BufferSticks.list({ action = "close" })

-- Alias for jumping to buffers (same as list with action="open")
BufferSticks.jump()

-- Alias for closing buffers (same as list with action="close")
BufferSticks.close()

-- Check if buffer list is visible
local visible = BufferSticks.is_visible()

-- Custom action function (buffer picker)
BufferSticks.list({
  action = function(buffer, leave)
    -- Do something with buffer.id, buffer.name, etc.
    print("Selected buffer: " .. buffer.name)
    leave() -- Call this to leave list mode
  end
})
```

## List mode

List mode allows you to quickly navigate to or close buffers by typing their first character(s):

**Navigate to buffers:**
1. Call `BufferSticks.list({ action = "open" })` or `BufferSticks.jump()`
2. Selection starts at the currently active buffer
3. Use `Up`/`Down` arrows (configurable) to navigate through buffers
4. Type the first character of the buffer you want to jump to
5. If multiple buffers match, continue typing more characters
6. Press `/` (configurable) to enter filter mode for fuzzy search
7. Press `Ctrl-Q` (configurable) to close the current active buffer
8. Press `Esc` or `Ctrl-C` to cancel

**Close buffers:**
1. Call `BufferSticks.list({ action = "close" })` or `BufferSticks.close()`
2. Selection starts at the currently active buffer
3. Use `Up`/`Down` arrows (configurable) to navigate through buffers
4. Type the first character of the buffer you want to close
5. If multiple buffers match, continue typing more characters
6. Press `/` (configurable) to enter filter mode for fuzzy search
7. Press `Ctrl-Q` (configurable) to close the current active buffer
8. Press `Esc` or `Ctrl-C` to cancel

## Filter mode

Filter buffers using fuzzy matching:

1. While in list mode, press `/` (configurable) to enter filter mode
2. Type to fuzzy search through buffers in real-time
3. Use `Up`/`Down` arrows (configurable) to navigate filtered results
4. Press `Enter` to select the highlighted buffer
5. Press `Esc` to exit filter mode back to list mode (previous selection is restored)

**Custom action function (buffer picker):**
1. Call `BufferSticks.list({ action = function(buffer, leave) ... end })`
2. Selection starts at the currently active buffer
3. Use `Up`/`Down` arrows or type the first character to select a buffer
4. If multiple buffers match, continue typing more characters
5. When a match is found (by typing) or when you press `Enter` (with arrow selection), your function is called with:
   - `buffer`: The selected buffer info (with `id`, `name`, `label`, etc.)
   - `leave`: Function to call when you're done to exit list mode
6. You control when to exit by calling `leave()`

**Label Display Options:**
- `label = { show = "always" }` - Always show buffer name labels
- `label = { show = "list" }` - Only show labels when in list mode (default)
- `label = { show = "never" }` - Never show labels

**List Mode Display Options:**
- **Default**: `list = { show = { "filename", "space", "label" } }`

**Available elements:**
- `"filename"` - Full filename
- `"space"` - Spaces between elements
- `"label"` - Unique character
- `"stick"` - Active/inactive character

## Preview

Buffer preview shows the content of the selected buffer while navigating in list or filter mode. Preview updates automatically as you move through buffers with arrow keys or type to filter.

**Preview Modes:**

- **`"float"`** - Displays buffer in a separate floating window
  - Configurable position: `"right"`, `"left"`, or `"below"`
  - Configurable size as fraction of screen
  - Customizable border, title, and footer
  - Default: right side, 50% width, 80% height, single border, filename as title

- **`"current"`** - Switches buffer in the current window
  - Shows immediate preview as you navigate
  - Press `Esc` to restore original buffer (cancel)
  - Press `Enter` or type label to confirm selection

- **`"last_window"`** - Previews in the window that was focused before entering list mode
  - Useful when you activate list mode from a split
  - Preview appears in your previous window while you navigate

**Configuration:**

```lua
preview = {
  enabled = true,        -- Enable/disable preview
  mode = "float",        -- "float", "current", or "last_window"
  float = {
    position = "right",  -- "right", "left", or "below"
    width = 0.5,         -- 0.0 to 1.0 (fraction of screen)
    height = 0.8,        -- 0.0 to 1.0 (fraction of screen)
    border = "rounded",  -- "none", "single", "double", "rounded", "solid", "shadow"
    title = nil,         -- nil/true = show filename (default), false = no title, "string" = custom title
    title_pos = "center", -- "left", "center", "right"
    footer = nil,        -- Window footer (optional)
    footer_pos = "center", -- "left", "center", "right"
  },
}
```

**Title options:**
- `title = nil` or `title = true` - Shows the buffer filename (default behavior)
- `title = false` - No title displayed
- `title = " Custom "` - Shows custom text

### Highlight Options

You can use hex colors:

```lua
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
}
```

Or link to existing highlight groups:

```lua
highlights = {
  active = { link = "Statement" },
  alternate = { link = "StorageClass" },
  inactive = { link = "Whitespace" },
  active_modified = { link = "Constant" },
  alternate_modified = { link = "Constant" },
  inactive_modified = { link = "Constant" },
  label = { link = "Comment" },
  filter_selected = { link = "Statement" },
  filter_title = { link = "Comment" },
  list_selected = { link = "Statement" },
}
```

## API

- `setup(opts)` - Initialize the plugin with configuration
- `toggle()` - Toggle buffer sticks visibility
- `show()` - Show buffer sticks
- `hide()` - Hide buffer sticks
- `list(opts)` - Enter list mode with action ("open", "close", or custom function)
- `jump()` - Enter list mode for quick buffer navigation (alias for `list({ action = "open" })`)
- `is_visible()` - Returns the visibility status
- `close()` - Enter list mode to close buffers (alias for `list({ action = "close" })`)

## Contributing

PRs are welcome! If you have ideas or find bugs, [open an issue](https://github.com/ahkohd/buffer-sticks.nvim/issues).
