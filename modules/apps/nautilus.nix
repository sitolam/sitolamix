{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.apps.nautilus;
in
{
  options.apps.nautilus.enable = lib.mkEnableOption "GNOME Files (nautilus) — bound to Mod+E in niri";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nautilus
      sushi # quick-look previews (spacebar)
      file-roller # archive extract/create integration
    ];

    # trash, network shares, MTP/gphoto, and removable-media mounting
    services.gvfs.enable = true;
    services.udisks2.enable = true;

    # right-click "Open in Terminal" -> ghostty
    programs.nautilus-open-any-terminal = {
      enable = true;
      terminal = "ghostty";
    };

    # gsettings backend for the extension + nautilus preferences
    programs.dconf.enable = true;
  };
}
