{ config, lib, ... }:
let
  cfg = config.apps.starship;
in
{
  options.apps.starship.enable = lib.mkEnableOption "starship prompt";

  config = lib.mkIf cfg.enable {
    home.extraOptions.programs.starship = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
