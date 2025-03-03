{ config, pkgs, lib, ... }:

{
  home = {
    file = {
      # Place the wezterm configuration file in the expected location
      ".wezterm.lua".source = ./wezterm/wezterm.lua;
    };
  };

  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm;
  };
}

