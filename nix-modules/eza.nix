{ lib, config, pkgs, ... }:
{
  programs.eza = {
      enable = true;
      icons = true;
      git = true;
      enableZshIntegration = false;
    };
}
