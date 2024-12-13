{ config, pkgs, ... }:
{
  home = {
    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'file'.
    file = {
        ".git_templates".source = ./git/git_templates;
        ".gitconfig".source = ./git/gitconfig;
        ".gitattributes".source = ./git/gitattributes;
        ".gitconfig-linux".source = ./git/gitconfig-linux;
        ".gitconfig-macos".source = ./git/gitconfig-macos;
        ".gitignore_global".source = ./git/gitignore_global;
        ".gitshrc".source = ./git/gitshrc;
    };
  };
  programs.git = {
    package = pkgs.gitAndTools.gitFull;
    enable = false; #true;
    userName = "Esteban Torres";
    userEmail = "me+github@estebantorr.es";
    signing = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMynlWjH+LLkyLyO1nwl4nc4l3yyixrvmFvBUSaB2nXe";
      signByDefault = true;
    };
    includes = [
      {
        condition = "gitdir:/Users";
        path = ./git/gitconfig-macos;
      }
      {
        condition = "gitdir:/home";
        path = ./git/gitconfig-linux;
      }
    ];
    aliases = {
      # cleanup merged branches
      cleanup = "!git branch --merged | grep  -v '\\*\\|master\\|beta' | xargs -n 1 git branch -d";
      cp = "cherry-pick";
      deleted = "log --diff-filter=D --summary";
      find-sha = "branch -avv --contains";
      graph = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(blue)<%an>%Creset' --abbrev-commit --date=relative";
      ours = "checkout --ours --";
      outgoing = "log --branches --not --remotes '--format=format:%C(auto,yellow)%h%C(auto,reset) %s %C(auto,blue)%d' --decorate";
      root = "rev-parse --show-toplevel";
      score = "shortlog --numbered --summary --no-merges";
      status = "status -sb";
      subpush = "push --recurse-submodules=check";
      po = "push origin ";
      sync = "fetch origin; rebase origin/master; push origin HEAD:master";
      puf = "pull --ff-only";
      pufo = "pull --ff-only origin";
      pur = "pull --ff --rebase";
      puro = "pull --ff --rebase origin";
      puo = "push -u origin";
      # Hide merges from the log
      log = "log --no-merges --name-status";
      undo = "checkout --";
      rno = "revert --no-commit";
      mbm = "merge-base -a master";

      # This is singlehandedly the most useful alias. If you borrow nothing else from this config, borrow this (and credential.helper)
      subup = "submodule update --init --recursive";
      theirs = "checkout --theirs --";

      report = "log --author=Esteban --format='%Cred%ci%Creset - %Cblue<%an>%Creset %Cgreen%+s%Creset' --no-merges";
      lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%C(bold blue)<%an>%Creset' --abbrev-commit";

      # From http://git-wt-commit.rubyforge.org
      wtf = "!git-wtf";

      # Frank Calma's alias to auto-resolve the remote
      ptom = "!git push origin $(git rev-parse --abbrev-ref HEAD)";
    };
    delta = {
      enable = true;
      options = {
          features = "side-by-side line-numbers decorations";
          whitespace-error-style = "22 reverse";
          plus-color = "syntax '#003800'";
          minus-color = "syntax '#3f0001'";
          syntax-theme = "Dracula";
          colorMoved = "default";
          decorations = {
            commit-decoration-style = "bold yellow box ul";
            file-style = "bold yellow ul";
            file-decoration-style = "none";
            hunk-header-decoration-style = "cyan box ul";
          };
          line-numbers = {
            line-numbers-left-style = "cyan";
            line-numbers-right-style = "cyan";
            line-numbers-minus-style = "124";
            line-numbers-plus-style = "28";
          };
      };
    };
  };
}
