{ config, pkgs, lib, inputs, system, ... }:
{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true; 

  # Direnv, load and unload environment variables depending on the current directory.
  # https://direnv.net
  # https://rycee.gitlab.io/home-manager/options.html#opt-programs.direnv.enable
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  imports = [
    ../nix-modules/zsh.nix
    ../nix-modules/atuin.nix
    ../nix-modules/tmux.nix
    ../nix-modules/git.nix
    ../nix-modules/neovim.nix
    ../nix-modules/wezterm.nix
    ../nix-modules/lazygit.nix
    ../nix-modules/gh.nix
    ../nix-modules/vscode.nix
    ../nix-modules/eza.nix
    ../nix-modules/ripgrep.nix
  ];

  nixpkgs.config = {
    allowUnfreePredicate = true;
  };

  disabledModules = ["targets/darwin/linkapps.nix"];

  home = {
    username = "esteban.torres";
    homeDirectory = lib.mkForce "/Users/esteban.torres/";
    stateVersion = builtins.trace (builtins.attrNames inputs) "23.05";

     sessionVariables = {
      EDITOR = "nvim";
    };
    packages = [
      config.nix.package
    ];
  };
}
