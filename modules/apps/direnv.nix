{ config, lib, ... }:
let
  cfg = config.apps.direnv;
in
{
  options.apps.direnv.enable = lib.mkEnableOption "direnv + nix-direnv";

  config = lib.mkIf cfg.enable {
    home.extraOptions.programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      config.global = {
        hide_env_diff = true;
        warn_timeout = "1m";
      };
    };
  };
}
