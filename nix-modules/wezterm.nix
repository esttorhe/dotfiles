{ config, pkgs, lib, ... }:

{
  home = {
    file = {
      # Place the wezterm configuration file in the expected location
      ".wezterm.lua".source = ./wezterm/wezterm.lua;
      ".wezterm.theme.lua".source = ./wezterm/wezterm.theme.lua;
    };
  };

  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm;
  };
}

