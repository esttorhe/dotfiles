{ config, pkgs, lib, ... }:
{
  extraConfig = {
    signing = {
      gpgPath = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    };
  };
}
