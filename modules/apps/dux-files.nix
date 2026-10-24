{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.apps.dux-files;
in
{
  # Safe to import unconditionally: it only acts once programs.dux-files.enable
  # is set (imports can't sit under an mkIf).
  imports = [ inputs.dux-files.nixosModules.default ];

  options.apps.dux-files = {
    enable = lib.mkEnableOption "Dux Files, Dux Labs' file manager (themed like the shell)";
    preferred = lib.mkEnableOption ''
      Dux Files as the file manager: Mod+E, the inode/directory handler and
      the open/save dialogs. Off leaves Nautilus in those roles'';
  };

  config = lib.mkIf cfg.enable {
    programs.dux-files = {
      enable = true;
      systemd.enable = true;
      # Registering the backend is harmless; only `preferred` routes dialogs to it.
      portal = {
        enable = true;
        inherit (cfg) preferred;
        desktop = "niri";
      };
    };

    # A niri-portals.conf in /etc replaces niri's own instead of merging with
    # it, so restate niri's defaults next to the FileChooser override.
    xdg.portal.config.niri = lib.mkIf cfg.preferred {
      default = [
        "gnome"
        "gtk"
      ];
      "org.freedesktop.impl.portal.Access" = [ "gtk" ];
      "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
      "org.freedesktop.impl.portal.Secret" = [
        "oo7-portal"
        "gnome-keyring"
      ];
    };
  };
}
