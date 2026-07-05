{ config, lib, ... }:
let
  cfg = config.services.docker;
in
{
  options.services.docker.enable = lib.mkEnableOption "Docker daemon with weekly autoprune";

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };
}
