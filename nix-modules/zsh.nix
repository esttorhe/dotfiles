{ lib, config, pkgs, ... }:
{
  home = {
      file = {
        ".zsh/".source = ./zsh/zsh;
        };
    };

  programs.zsh = {
      enable = true;
      enableAutosuggestions = false;
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
              rev = "v0.4.0";
              sha256 = "0z6i9wjjklb4lvr7zjhbphibsyx51psv50gm07mbb0kj9058j6kc";
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
