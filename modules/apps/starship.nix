{ config, lib, ... }:
let
  cfg = config.apps.starship;
in
{
  options.apps.starship.enable = lib.mkEnableOption "starship prompt";

  config = lib.mkIf cfg.enable {
    # default starship prompt; stylix's starship target still themes it (sets
    # palette = "base16" from the active scheme).
    home.extraOptions.programs.starship = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
