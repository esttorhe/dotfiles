{ lib, config, pkgs, ... }:
{
  programs.exa = {
      enable = true;
      icons = true;
      git = true;
    };
}
