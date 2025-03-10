--local wezterm = require("wezterm")
--
--return {
--	-- Dracula Theme
--	color_scheme = "Dracula",
--
--	-- Font settings
--	font = wezterm.font("FiraCode Nerd Font Propo"),
--	font_size = 11.5,
--
--	-- Window settings
--	window_background_opacity = 0.75,
--	hide_mouse_cursor_when_typing = true,
--	window_padding = {
--		left = 14,
--		right = 14,
--		top = 10,
--		bottom = 10,
--	},
--
--	-- Hide window decorations (no title bar, no border)
--	window_decorations = "RESIZE",
--
--	-- Disable the tab bar to match Alacritty’s "buttonless" style
--	enable_tab_bar = false,
--
--	-- Keybindings converted from Alacritty
--	keys = {
--		{ key = "1", mods = "CMD", action = wezterm.action.SendString("\x021") },
--		{ key = "2", mods = "CMD", action = wezterm.action.SendString("\x022") },
--		{ key = "3", mods = "CMD", action = wezterm.action.SendString("\x023") },
--		{ key = "4", mods = "CMD", action = wezterm.action.SendString("\x024") },
--		{ key = "5", mods = "CMD", action = wezterm.action.SendString("\x025") },
--		{ key = "6", mods = "CMD", action = wezterm.action.SendString("\x026") },
--		{ key = "7", mods = "CMD", action = wezterm.action.SendString("\x027") },
--		{ key = "8", mods = "CMD", action = wezterm.action.SendString("\x028") },
--		{ key = "9", mods = "CMD", action = wezterm.action.SendString("\x029") },
--		{ key = ",", mods = "CMD", action = wezterm.action.SendString("\x02,") },
--		{ key = "E", mods = "CMD", action = wezterm.action.SendString('\x02"') },
--		{ key = "E", mods = "CMD|SHIFT", action = wezterm.action.SendString("\x02%") },
--		{ key = "Q", mods = "CTRL", action = wezterm.action.SendString(":q\n") },
--		{ key = "S", mods = "CMD", action = wezterm.action.SendString("\x1bw\n") },
--		{ key = "S", mods = "CTRL", action = wezterm.action.SendString("\x1bw\n") },
--		{ key = "S", mods = "CMD|SHIFT", action = wezterm.action.SendString(":wa\n") },
--		{ key = ";", mods = "CTRL", action = wezterm.action.SendString("\x02:") },
--		{ key = "T", mods = "CMD", action = wezterm.action.SendString("\x02c") },
--		{ key = "W", mods = "CMD", action = wezterm.action.SendString("\x02x") },
--		{ key = "Z", mods = "CMD", action = wezterm.action.SendString("\x02z") },
--	},
--}

local wezterm = require("wezterm")
local mappings = require("mappings")
local theme = require("theme")
local tab_bar = require("tab_bar")

local config = wezterm.config_builder()

config.font = wezterm.font("FiraCode Nerd Font Propo")
config.disable_default_key_bindings = true
config.font_size = 12.5
config.window_background_opacity = 0.75

config.inactive_pane_hsb = {
	saturation = 0.9,
	brightness = 0.2,
}

mappings.apply_to_config(config)
--theme.apply_to_config(config)
config.color_scheme = "Dracula"
tab_bar.apply_to_config(config)

return config
