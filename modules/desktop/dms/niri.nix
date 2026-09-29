{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.dms.enable {
    home.extraOptions =
      { lib, ... }:
      {
        programs = {
          # Let DMS manage niri outputs from its settings UI: it writes display
          # config to ~/.config/niri/dms/outputs.kdl, and this include
          # mechanism relocates our niri config to niri/hm.kdl so config.kdl
          # includes both, letting DMS's output changes persist.
          # binds/layout/wpblur stay ours; override=true (default) means DMS's
          # outputs win over the defaults in hosts/gamingpc.
          dank-material-shell.niri.includes = {
            enable = true;
            # "colors" is DMS's matugen-rendered focus ring, border, shadow,
            # tab indicator and insert hint — why niri/appearance.nix sets none.
            filesToInclude = [
              "outputs"
              "colors"
            ];
          };

          niri.settings = {
            # Pin DMS's blurred-wallpaper duplicate into the overview backdrop
            # (visible only there, never on the desktop) — the manual niri
            # config blurredWallpaperLayer (theme.nix) requires. The layer is
            # a Background surface ignoring exclusive zones, as needed by
            # place-within-backdrop.
            layer-rules = [
              {
                matches = [ { namespace = "^dms:blurwallpaper$"; } ];
                place-within-backdrop = true;
              }
            ];
          };
        };

        # niri reads its config, incl. the dms/outputs.kdl include, before DMS
        # runs — seed an empty file if absent to avoid a missing-include
        # error. Not a home.file symlink: DMS must be able to overwrite it.
        home.activation.dmsOutputsPlaceholder = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          f="$HOME/.config/niri/dms/outputs.kdl"
          if [ ! -e "$f" ]; then
            run mkdir -p "$(dirname "$f")"
            run touch "$f"
          fi
        '';
      };
  };
}
