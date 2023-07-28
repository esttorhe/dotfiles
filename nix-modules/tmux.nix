{ config, pkgs, ... }:
let 
  tmux-prefix-highlight = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-prefix-highlight";
    version = "1.0";
    src = pkgs.fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "tmux-prefix-highlight";
      rev = "15acc6172300bc2eb13c81718dc53da6ae69de4f";
      sha256 = "sha256-9LWRV0Hw8MmDwn5hWl3DrBuYUqBjLCO02K9bbx11MyM=";
    };
  };

  tmux-fzf-url = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-fzf-url";
    version = "1.0";
    src = pkgs.fetchFromGitHub {
      owner = "wfxr";
      repo = "tmux-fzf-url";
      rev = "93ca6fc03a87627153f6e67ea81a1c01e1e44988";
      sha256 = "sha256-c/x0+innvhhb4SxQpV1tLl9bHVtV6ioaWY6POv/jqNk=";
    };
  };

  tmux-nerd-font-window-name = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-nerd-font-window-name";
    version = "v1.2.2";
    src = pkgs.fetchFromGitHub {
      owner = "joshmedeski";
      repo = "tmux-nerd-font-window-name";
      rev = "60d4feb4dd86113084d46f7307f0f8de85708646";
      sha256 = "sha256-jHfyXb2n0mqSKdo/0sEH3F44idHMKC9rK3vQbhhLGoM=";
    };
  };

  t-smart-tmux-session-manager = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "t-smart-tmux-session-manager";
    version = "v1.8.1";
    src = pkgs.fetchFromGitHub {
      owner = "joshmedeski";
      repo = "t-smart-tmux-session-manager";
      rev = "0a4c77c5c3858814621597a8d3997948b3cdd35d";
      sha256 = "sha256-RSQ7VyRNBu61EOwdlK95RPq5u77hSsKjwAR5oATgJbc=";
    };
  };

  tmux-sidebar = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-sidebar";
    version = "v0.8.x";
    src = pkgs.fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "tmux-sidebar";
      rev = "a41d72c019093fd6a1216b044e111dd300684f1a";
      sha256 = "sha256-5+ISvoXXYDDfzSoPBO6v6Wt7IWsRVb9DcPgnO02rYd4=";
    };
  };

  tmuxifier = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmuxifier";
    version = "v0.13.x";
    src = pkgs.fetchFromGitHub {
      owner = "jimeh";
      repo = "tmuxifier";
      rev = "fe1f6c473477dd9aba37458fedd3b704c9288d3c";
      sha256 = "sha256-7j6nWsecPw7HplAssTnyyH/W9gR/SnFAfw9b6HpDh0s=";
    };
  };

  vim-tmux-focus-events = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "vim-tmux-focus-events";
    version = "v1.0.x";
    src = pkgs.fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "vim-tmux-focus-events";
      rev = "b1330e04ffb95ede8e02b2f7df1f238190c67056";
      sha256 = "sha256-R40ggkvFFcHk9lhVm9nw8b174VfUrlDiy+BUgql+KKc=";
    };
  };
  
in
{
  home = {
      # Home Manager is pretty good at managing dotfiles. The primary way to manage
      # plain files is through 'file'.
      file = {
        ".tmux.conf.funcs".source = ./tmux/tmux.conf.funcs;
        ".tmux_dev".source = ./tmux/tmux_dev;
      };
  };

  programs.tmux = {
    enable = true;
    sensibleOnTop = false;
    keyMode = "vi";
    clock24 = true;
    prefix = "C-x";
    
    plugins = with pkgs.tmuxPlugins; [
      yank
	    {
	    	plugin = dracula;
	    	extraConfig = ''
          set -g @dracula-show-powerline true
          set -g @dracula-show-flags true

          # it can accept `session`, `smiley`, `window`, or any character.
          set -g @dracula-left-icon-padding 0
          set -g @dracula-show-left-icon '' #
          set -g @dracula-border-contrast true
          set -g @dracula-day-month true
          set -g @dracula-military-time true
          set -g @dracula-show-timezone false

          # available plugins: battery, cpu-usage, git, gpu-usage, ram-usage, network, network-bandwidth, network-ping, weather, time
          set -g @dracula-plugins "git network battery weather time"
          set -g @dracula-show-fahrenheit false
	    	'';
	    }
      tmux-prefix-highlight
      tmux-fzf-url
      tmux-nerd-font-window-name
      tmux-sidebar
      tmuxifier
      vim-tmux-focus-events
      t-smart-tmux-session-manager
    ];
    extraConfig = (builtins.readFile ./tmux/tmux.conf);
  };
}
