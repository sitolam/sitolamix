{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.niri.enable {
    home.extraOptions.programs.niri.settings = {
      input = {
        keyboard.xkb = {
          layout = "us";
          variant = "intl";
          options = "compose:ralt";
        };
        touchpad = {
          # false = traditional scroll direction (content moves opposite the
          # fingers). true is the "natural"/touch-screen-like inversion that
          # felt backwards on omnibook.
          natural-scroll = false;
          # default is 1.0; 0.5 was still way too fast on the omnibook trackpad.
          scroll-factor = 0.25;
          tap = true;
          tap-button-map = "left-right-middle";
          middle-emulation = true;
          # keep the touchpad live even with a mouse connected: the bluetooth
          # mouse is often out of reach and libinput counts it as external,
          # so the default true left the laptop with no pointer at all.
          disabled-on-external-mouse = false;
          scroll-method = "two-finger";
        };
        focus-follows-mouse = {
          enable = true;
          max-scroll-amount = "10%";
        };
        warp-mouse-to-focus.enable = true;
        workspace-auto-back-and-forth = true;
      };

      # static workspace that niri-scratchpad-rs stashes windows onto (required
      # by the tool; see bindings.nix Mod+M/Mod+S and startup.nix daemon).
      workspaces."stash" = { };

      # The music workspace: cliamp (Mod+Alt+C) and Spotify (Mod+Alt+F) both
      # open here, pinned by open-on-workspace rules in their own modules.
      # Declared here rather than in either app module because two features
      # share it — and because a named workspace is a property of the desktop,
      # not of the app that happens to land on it. Named workspaces always
      # exist and sort before the dynamic ones, so this one costs an index in
      # the Mod+<n> row, same as "stash" already does.
      workspaces."music" = { };

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
        # GTK 4.20+ dropped built-in compose/dead-key handling on Wayland when no
        # input method is running, breaking us-intl dead keys in GTK apps like
        # ghostty. Force the classic simple IM to get dead keys/compose back.
        GTK_IM_MODULE = "simple";
      };
    };
  };
}
