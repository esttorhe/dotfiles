local wezterm = require("wezterm")
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
local icons = wezterm.nerdfonts

local M = {}

local function get_icon(title)
	if title == "nvim" or title == "vim" then
		return icons.custom_neovim
	elseif title == "lazygit" then
		return icons.dev_git
	elseif title == "lazydocker" then
		return icons.dev_docker
	elseif title == "atac" or title == "apis" then
		return icons.md_api
	end
	return icons.oct_terminal
end

local function tab_title(tab)
	if tab.tab_title and #tab.tab_title > 0 then
		return tab.tab_title
	end
	local active_pane_title = tab.active_pane.title
	if string.match(active_pane_title, "^~") ~= nil then
		return icons.cod_home
	end
	if string.match(active_pane_title, "^%.%.") ~= nil then
		return icons.custom_folder_open
	end
	return get_icon(tab.active_pane.title)
end

local function process_name(tab)
	if tab.tab_title and #tab.tab_title > 0 then
		return tab.tab_title
	end
	local active_pane_title = tab.active_pane.title
	if string.match(active_pane_title, "^~") ~= nil then
		return active_pane_title
	end
	if string.match(active_pane_title, "^%.%.") ~= nil then
		return "../" .. active_pane_title:match("([^/\\]+)[/\\]?$")
	end
	return tab.active_pane.title
end

local colors = {
	bg = "#16181a",
	bg_alt = "#1e2124",
	bg_highlight = "#3c4048",
	fg = "#ffffff",
	grey = "#7b8496",
	blue = "#5ea1ff",
	green = "#5eff6c",
	cyan = "#5ef1ff",
	red = "#ff6e5e",
	yellow = "#f1ff5e",
	magenta = "#ff5ef1",
	pink = "#ff5ea0",
	orange = "#ffbd5e",
	purple = "#bd5eff",
}

local function get_config(c)
	local is_work = os.getenv("USER") == "esteban.torres"
	local tabline_x = { "ram", "cpu" }

	if is_work then
		table.insert(tabline_x, "battery")
	end

	return {
		options = {
			icons_enabled = true,
			theme = c.colors,
			tabs_enabled = true,
			theme_overrides = {
				normal_mode = {
					a = { bg = colors.cyan },
					x = { fg = colors.fg },
					y = { fg = colors.purple },
				},
				tab = {
					active = { fg = colors.magenta },
					inactive = { fg = colors.grey },
					inactive_hover = { fg = colors.magenta },
				},
			},
			section_separators = {
				left = wezterm.nerdfonts.pl_left_hard_divider,
				right = wezterm.nerdfonts.pl_right_hard_divider,
			},
			component_separators = {
				left = wezterm.nerdfonts.pl_left_soft_divider,
				right = wezterm.nerdfonts.pl_right_soft_divider,
			},
			tab_separators = {
				left = wezterm.nerdfonts.pl_left_hard_divider,
				right = wezterm.nerdfonts.pl_right_hard_divider,
			},
		},
		sections = {
			tabline_a = { "mode" },
			tabline_b = {},
			tabline_c = {},
			tab_active = { tab_title, " ", process_name },
			tab_inactive = { tab_title },
			tabline_x = tabline_x,
			tabline_y = { "datetime" },
			tabline_z = {},
		},
		extensions = {},
	}
end

local function apply_to_config(c)
	tabline.setup(get_config(c))
	tabline.apply_to_config(c)

	c.show_tabs_in_tab_bar = true
end

M.apply_to_config = apply_to_config

return M
