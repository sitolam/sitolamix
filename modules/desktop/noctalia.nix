{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.desktop.noctalia;
in
{
  options.desktop.noctalia.enable = lib.mkEnableOption "noctalia shell (bar + panels)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    ]
    # runtime deps for the noctalia plugins we use (enable them via `noctalia
    # plugin` / the plugin panel; v5 has no declarative plugin config).
    ++ (with pkgs; [
      # screen-toolkit: screenshot / OCR / record
      grim
      slurp
      wl-clipboard
      tesseract
      imagemagick
      wl-screenrec
      ffmpeg
      # usb-drive-manager
      udisks
      util-linux
    ]);

    home.extraOptions =
      { lib, ... }:
      {
        imports = [ inputs.noctalia.homeModules.default ];

        programs.noctalia = {
          enable = true;
          systemd.enable = true;

          settings = lib.mkForce {
            shell = {
              corner_radius_scale = 1.25;
              avatar_path = toString ../../assets/avatar.png;
              shadow = {
                direction = "down";
                alpha = 0.52;
              };
              panel = {
                background_blur = true;
                transparency_mode = "glass";
                borders = true;
                shadow = true;
                launcher_placement = "floating";
                clipboard_placement = "floating";
                control_center_placement = "attached";
                wallpaper_placement = "attached";
                session_placement = "attached";
              };
            };

            backdrop = {
              enabled = true;
              blur_intensity = 0.85;
              tint_intensity = 0.45;
            };

            # lock screen: blurred desktop snapshot as background + media widget.
            lockscreen = {
              enabled = true;
              blurred_desktop = true;
              blur_intensity = 0.6;
              tint_intensity = 0.35;
            };

            # positioned widgets shown on the lock screen (v5 lockscreen_widgets).
            # media_main = now-playing/media controls, centered-ish on the primary output.
            lockscreen_widgets = {
              enabled = true;
              widget_order = [ "media_main" ];
              widget.media_main = {
                type = "media";
                output = "DP-3";
                cx = 960.0;
                cy = 820.0;
                scale = 1.0;
                rotation = 0.0;
              };
            };

            # stylix drives every other app; noctalia's bar reads the same wallpaper.
            # If colors ever drift, switch source to "predefined" + set a catppuccin scheme name.
            theme = {
              mode = "dark";
              source = "wallpaper";
              wallpaper_scheme = "m3-tonal-spot";
              templates = {
                enable_builtin_templates = false;
                builtin_ids = [ ];
              };
            };

            wallpaper = {
              enabled = true;
              fill_mode = "crop";
              transition = [ "fade" ];
              transition_duration = 1500;
              edge_smoothness = 0.3;
              directory = toString ../../assets;
              default = toString ../../assets/wallpaper.jpg;
            };

            bar.default = {
              background_opacity = 0.58;
              radius = 18;
              margin_ends = 300;
              margin_edge = 10;
              shadow = true;
              start = [
                "launcher"
                "wallpaper"
                "workspaces"
                "active_window"
                "sysmon"
              ];
              center = [ "clock" ];
              end = [
                "media"
                "tray"
                "notifications"
                "clipboard"
                "network"
                "bluetooth"
                "volume"
                "brightness"
                "battery"
                "screenshot"
                "theme_mode"
                "control-center"
                "session"
              ];
            };

            widget.workspaces = {
              type = "workspaces";
              minimal = true;
            };

            notification.background_opacity = 0.78;
            osd.background_opacity = 0.78;
          };
        };
      };
  };
}
