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
      #aliasApplications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      #    baseDir="$HOME/Applications/Home Manager Apps"
      #    if [ -d "$baseDir" ]; then
      #      rm -rf "$baseDir"
      #    fi
      #    mkdir -p "$baseDir"
      #    app_folder=$(echo ~/Applications);
      #    for app in "$(find "$genProfilePath/home-path/Applications" -type l)"; do
      #      app_name=$(basename "$app")
      #      $DRY_RUN_CMD echo "$app_name"
      #      #$DRY_RUN_CMD rm -f "$app_folder"/"$app_name"
      #      #$DRY_RUN_CMD /usr/bin/osascript -e "tell app \"Finder\"" -e "make new alias file at POSIX file \"$app_folder\" to POSIX file \"$app_name\"" -e "set name of result to \"$app_name\"" -e "end tell"
      #    done
      #  '';

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
          $DRY_RUN_CMD cp ''${VERBOSE_ARG:+-v} -fHRL "$appFile" "$baseDir"
          $DRY_RUN_CMD chmod ''${VERBOSE_ARG:+-v} -R +w "$target"
        done
      '';
    };

    username = "esteban.torres";
    homeDirectory = lib.mkForce "/Users/esteban.torres/";
    stateVersion = builtins.trace (builtins.attrNames inputs) "23.05";

    packages = with pkgs; [
       docker
       mosh
       jq
       ripgrep
       ripgrep-all
       git-crypt
       zsh-syntax-highlighting
       wget
       htop
       fzf
       imagemagick
       httpie
       discord
       spotify
       obsidian
       slack
       rescuetime
       keybase
       meld
       wtf
       restic
    ];

    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
