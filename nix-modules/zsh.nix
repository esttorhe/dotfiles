{ lib, config, pkgs, ... }:
{
  home = {
      file = {
        ".zsh/".source = ./zsh/zsh;
        };
    };

  programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      defaultKeymap = "viins";
      dotDir = ".config/zsh";
      syntaxHighlighting = {
        enable = true;
        };
      shellAliases = {
          gst = "git status";
          ga = "git add";
          gb = "git branch";
          gp = "git push";
          gcmsg = "git commit -m";
          grbi = "git rebase -i";
          grbc = "git rebase --continue";
          grba = "git rebase --abort";
          gc = "git commit";
          gd = "git diff";
          gco = "git checkout";
          "gc!" = "git commit --amend";
        };
      initExtraBeforeCompInit = (builtins.readFile ./zsh/zshrc);
      plugins = [
        {
            name = "zsh-autosuggestions";
            src = pkgs.fetchFromGitHub {
              owner = "zsh-users";
              repo = "zsh-autosuggestions";
              rev = "c3d4e576c9c86eac62884bd47c01f6faed043fc5";
              sha256 = "sha256-B+Kz3B7d97CM/3ztpQyVkE6EfMipVF8Y4HJNfSRXHtU=";
            };
          }
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
      ];
      oh-my-zsh = {
          enable = true;
          plugins = [
            "z"
            "git"
            "docker"
          ];
        };
    }; 
}
