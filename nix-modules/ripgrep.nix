{ config, pkgs, ... }:
{
  home = {
    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'file'.
    file = {
      ".config/ripgrepcr".source = ./ripgrep/ripgrepcr;
    };
  };

  programs.ripgrep = {
    enable = true;
  };
}
