{ config, pkgs, lib, inputs, system, ... }:
{
  imports = [
    ../nix-modules/zsh.nix
    ../nix-modules/tmux.nix
    ../nix-modules/git.nix
    ../nix-modules/neovim.nix
    ../nix-modules/alacritty.nix
    ../nix-modules/atuin.nix
    ../nix-modules/gh.nix
    ../nix-modules/vscode.nix
    ../nix-modules/exa.nix
    ../nix-modules/ripgrep.nix
  ];

  nixpkgs.config = {
    allowUnfreePredicate = true;
  };

  disabledModules = ["targets/darwin/linkapps.nix"];

  home = {
    file = {
        ".restic-keys".source = ../nix-modules/restic/restic-keys;
        ".restic-cron".source = ../nix-modules/restic/restic-cron;
      };

	  activation = {
      copyApplications = let
          apps = pkgs.buildEnv {
            name = "home-manager-applications";
            paths = config.home.packages;
            pathsToLink = "/Applications";
          };
      in
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        baseDir="$HOME/Applications"
        #if [ -d "$baseDir" ]; then
        #  rm -rf "$baseDir"
        #fi
        mkdir -p "$baseDir"
        for appFile in ${apps}/Applications/*; do
          target="$baseDir/$(basename "$appFile")"
          if [ -d "$target" ]; then
            rm -rf "$target"
          fi
          $DRY_RUN_CMD cp ''${VERBOSE_ARG:+-v} -rfHRL "$appFile" "$baseDir"
          $DRY_RUN_CMD chmod ''${VERBOSE_ARG:+-v} -R +w "$target"
        done
      '';
    };

    username = "esteban.torres";
    homeDirectory = lib.mkForce "/Users/esteban.torres/";
    stateVersion = builtins.trace (builtins.attrNames inputs) "23.05";

    packages = with pkgs; [
       discord
       docker
       fzf
       fx
       git-crypt
       htop
       httpie
       imagemagick
       jq
       keybase
       libsixel
       meld
       mosh
       obsidian
       raycast
       rescuetime
       restic
       ripgrep
       ripgrep-all
       slack
       spotify
       todoist-electron
       wget
       wtf
       zsh-syntax-highlighting
    ];

    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
