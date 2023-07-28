{ config, pkgs, ... }:
{
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "nvim";
      prompt = "enabled";
      hosts = {
        user = "esttorhe";
      };
      aliases = {
        co = "pr checkout";
        pv = "pr view";
      };
    };
  };
}
