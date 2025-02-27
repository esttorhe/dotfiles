{ config, pkgs, lib, ... }: 
{
  home = {
    file = {
      ".wezterm.lua".source = ./wezterm/wezterm.lua;
    };
  };

  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm;
    settings = {
      color_scheme = "Dracula";
      font = {
        family = "FiraCode Nerd Font Propo";
        size = 11.5;
      };
      enable_tab_bar = false; # Alacritty doesn’t show a tab bar by default
      window_background_opacity = 0.75;
      window_padding = {
        left = 14;
        right = 14;
        top = 10;
        bottom = 10;
      };
      hide_mouse_cursor_when_typing = true;
    };
  };
}

