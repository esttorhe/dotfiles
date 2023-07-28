{ config, pkgs, ... }:
{
  home = {
    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'file'.
    file = {
      ".nvim/init.lua".source = ./neovim/config/init.lua;
      ".config/nvim/stylua.toml".source = ./neovim/config/stylua.toml;
      ".config/nvim/lua/".source = ./neovim/config/lua;
    };
  };
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
    extraConfig = ":luafile ~/.nvim/init.lua";
  };
}
