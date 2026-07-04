_:
{
  flake.modules.homeManager.shared = {
    programs.niri.settings = {
      input = {
        keyboard.xkb = {
          layout = "us";
          variant = "intl";
          options = "compose:ralt";
        };
        touchpad = {
          natural-scroll = true;
          tap = true;
          tap-button-map = "left-right-middle";
          middle-emulation = true;
          disabled-on-external-mouse = true;
          scroll-method = "two-finger";
        };
        focus-follows-mouse = {
          enable = true;
          max-scroll-amount = "10%";
        };
        warp-mouse-to-focus.enable = true;
        workspace-auto-back-and-forth = true;
      };

      layout = {
        gaps = 20;
        center-focused-column = "never";
        always-center-single-column = false;
        focus-ring.enable = true;
        border.enable = false;
        preset-column-widths = [
          { proportion = 0.33333; }
          { proportion = 0.5; }
          { proportion = 0.66667; }
          { proportion = 1.0; }
        ];
        default-column-width.proportion = 0.5;
      };

      environment = {
        CLUTTER_BACKEND = "wayland";
        GDK_BACKEND = "wayland,x11";
        MOZ_ENABLE_WAYLAND = "1";
        NIXOS_OZONE_WL = "1";
        QT_QPA_PLATFORM = "wayland";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
        XDG_SESSION_TYPE = "wayland";
        XDG_CURRENT_DESKTOP = "niri";
      };
    };
  };
}
