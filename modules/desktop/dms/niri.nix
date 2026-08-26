{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.dms.enable {
    home.extraOptions =
      { lib, ... }:
      {
        programs = {
          # Let DMS manage niri outputs from its settings UI. It writes display
          # config to ~/.config/niri/dms/outputs.kdl; this include mechanism
          # relocates our niri config to niri/hm.kdl and makes config.kdl include
          # both — so DMS's output changes persist. We only pull in "outputs"
          # (binds/layout/colors/wpblur stay ours). override=true (default) means
          # DMS's outputs win over the defaults in hosts/gamingpc.
          dank-material-shell.niri.includes = {
            enable = true;
            filesToInclude = [ "outputs" ];
          };

          niri.settings = {
            # DMS honours DMS_DISABLE_MATUGEN to skip generating app theme
            # templates entirely; merges with the environment block in
            # niri/layout.nix.
            environment.DMS_DISABLE_MATUGEN = "1";

            # Pin DMS's blurred-wallpaper duplicate into niri's overview backdrop,
            # so it's only visible in the overview / between workspaces (never on
            # the normal desktop). This is the "manual niri configuration" that
            # the blurredWallpaperLayer setting (see theme.nix) requires. The
            # layer is a Background surface that ignores exclusive zones, as
            # place-within-backdrop needs.
            layer-rules = [
              {
                matches = [ { namespace = "^dms:blurwallpaper$"; } ];
                place-within-backdrop = true;
              }
            ];
          };
        };

        # niri reads its config (incl. the dms/outputs.kdl include) at startup,
        # before DMS runs — so seed an empty outputs file if absent to avoid a
        # missing-include error. Not a home.file symlink: DMS must be able to
        # overwrite it when you change displays.
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
