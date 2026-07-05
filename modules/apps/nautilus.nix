{ config, lib, ... }:
let
  cfg = config.apps.nautilus;
in
{
  options.apps.nautilus.enable = lib.mkEnableOption "GNOME Files (nautilus) — bound to Mod+E in niri";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          nautilus
          sushi # quick-look previews for nautilus
        ];
      };
  };
}
