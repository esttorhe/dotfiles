{ lib, config, pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    userSettings = {
      "JSON-zain.json.autorefresh" = true;
      "editor.accessibilitySupport" = "off";
      "editor.unicodeHighlight.ambiguousCharacters" = false;
      "editor.unicodeHighlight.nonBasicASCII" = false;
      "go.toolsManagement.autoUpdate" = true;
      "security.workspace.trust.untrustedFiles" = "open";
      "terminal.integrated.defaultProfile.linux" = "zsh";
      "workbench.colorTheme" = "Default Dark+";
      "workbench.iconTheme" = "vscode-icons";
      "go.autocompleteUnimportedPackages" = true;
      "go.docsTool" = "gogetdoc";
      "editor.inlineSuggest.enabled" = true;
      "github.copilot.enable" = {
        "*" = true;
        "plaintext" = false;
        "markdown" = true;
        "scminput" = false;
      };
    };
  };
}
