{ lib, config, pkgs, ... }:
{
  # Make sure the nix daemon always runs
  services.nix-daemon.enable = true;
  nixpkgs.config.allowUnsupportedSystem = true;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "discord"
    "spotify"
    "obsidian"
    "slack"
    "rescuetime"
    "vscode"
  ];

  imports = [ ./system.nix ];

  homebrew = {
    enable = true;
    onActivation.upgrade = true; 
    onActivation.autoUpdate = true;
    casks = [
      "amethyst"
      "1password-cli"
      "anki"
      "arq"
      "daisydisk"
      "imageoptim"
      "keybase"
      "kindle"
      "monitorcontrol"
      "notion"
      "proxyman"
      "rescuetime"
      "selfcontrol"
      "sequel-pro"
      "teensy"
      "wkhtmltopdf"
    ];
  };
}
