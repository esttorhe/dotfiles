{ config, pkgs, ... }:
{
  home = {
    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'file'.
    file = {
      ".config/ripgreprc".source = ./ripgrep/ripgreprc;
    };
  };

  programs.ripgrep = {
    enable = true;
  };
}
