{ config, pkgs, lib, ... }: 
{
  home = {
    file = {
      ".alacritty_dracula.yml".source = ./alacritty/alacritty_dracula.yml;
    };
  };
  programs.alacritty = {
    enable = true;
    package = pkgs.alacritty;
    settings = {
      live_config_reload = true;
      import = [
        "~/.alacritty_dracula.yml"
      ];
      env = {
        TERM = "xterm-screen-256color";
      };
      font = {
        normal = {
          family = "FiraCode Nerd Font Propo";
          style = "Regular";
        };
        bold = {
          family = "FiraCode Nerd Font Propo";
          style = "Bold";
        };
        italic = {
          family = "FiraCode Nerd Font Propo";
          style = "Italic";
        };
        size = 11.5;
      };
      window = {
        opacity = 0.75;
        padding = {
          x = 14;
          y = 10;
        };
        dynamic_padding = false;
        decorations = "buttonless";
      };
      mouse = {
        hide_when_typing = true;
      };
    };
  };
}
