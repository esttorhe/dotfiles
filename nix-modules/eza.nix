{ lib, config, pkgs, ... }:
{
  programs.eza = {
      enable = true;
      icons = "auto";
      git = true;
      enableZshIntegration = false;
    };
}
