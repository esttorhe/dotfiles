local wezterm = require("wezterm")
local theme = require("wezterm.theme")
local mappings = require("mappings")

local config = wezterm.config_builder()

-- Dracula Theme
config.color_scheme = "Dracula"

-- Font settings
config.font = wezterm.font("FiraCode Nerd Font Propo")
config.font_size = 11.5

-- Window settings
config.window_background_opacity = 0.75
config.hide_mouse_cursor_when_typing = true
config.window_decorations = "RESIZE"
config.enable_tab_bar = false

config.window_padding = {
	left = 14,
	right = 14,
	top = 10,
	bottom = 10,
}

-- Apply modular configurations
mappings.apply_to_config(config)
theme.apply_to_config(config)

return config
