{ config, pkgs, lib, ... }:

{
  home = {
    file = {
      # Place the wezterm configuration file in the expected location
      ".wezterm.lua".source = ./wezterm/wezterm.lua;
      #".theme.lua".source = ./wezterm/theme.lua;
      ".mappings.lua".source = ./wezterm/mappings.lua;
    };
  };

  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm;
  };
}

