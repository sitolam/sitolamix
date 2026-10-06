# Named drawing-tablet, not opentabletdriver: nixpkgs already owns
# hardware.opentabletdriver, which this wraps.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.drawing-tablet;
  otd = config.hardware.opentabletdriver.package;

  binding = type: property: value: {
    Path = "OpenTabletDriver.Desktop.Binding.${type}";
    Settings = [
      {
        Property = property;
        Value = value;
      }
    ];
    Enable = true;
  };

  # Smoothing filter for handwriting. A driver plugin from its author's own
  # release, not nixpkgs: nixpkgs packages no OpenTabletDriver plugins.
  radialFollow = pkgs.fetchzip {
    url = "https://github.com/AbstractQbit/AbstractOTDPlugins/releases/download/0.3.0/RadialFollow.zip";
    hash = "sha256-3ipNyXoywh/rZMx66cHqOLvIx0URfPWPJWfWRE+2L0Y=";
    stripRoot = false;
  };

  # tablet-sync fills in the display area, the matching tablet area and key 1
  # (next screen) per connected monitor; the areas here are only the tablet's
  # full size for it to start from.
  settings = pkgs.writeText "opentabletdriver-settings.json" (
    builtins.toJSON {
      Revision = otd.version;
      Profiles = [
        {
          Tablet = "Gaomon S620";
          # Artist Mode is the pen mode: absolute position with pressure.
          OutputMode = {
            Path = "OpenTabletDriver.Desktop.Output.LinuxArtistMode";
            Settings = [ ];
            Enable = true;
          };
          Filters = [
            {
              Path = "RadialFollow.RadialFollowSmoothingTabletSpace";
              # mm on the tablet. Larger radii smooth more but round off small letters.
              Settings = [
                {
                  Property = "Outer Radius";
                  Value = 0.7;
                }
                {
                  Property = "Inner Radius";
                  Value = 0.15;
                }
                {
                  Property = "Initial Smoothing Coefficient";
                  Value = 0.93;
                }
                {
                  Property = "Soft Knee Scale";
                  Value = 1.0;
                }
                {
                  Property = "Smoothing Leak Coefficient";
                  Value = 0.0;
                }
              ];
              Enable = true;
            }
          ];
          AbsoluteModeSettings = {
            Display = {
              Width = 1920.0;
              Height = 1080.0;
              X = 960.0;
              Y = 540.0;
              Rotation = 0.0;
            };
            Tablet = {
              Width = 165.1;
              Height = 101.6;
              X = 82.55;
              Y = 50.8;
              Rotation = 0.0;
            };
            EnableClipping = true;
            EnableAreaLimiting = false;
            LockAspectRatio = true;
          };
          RelativeModeSettings = {
            XSensitivity = 10.0;
            YSensitivity = 10.0;
            RelativeRotation = 0.0;
            RelativeResetDelay = "00:00:00.1000000";
          };
          Bindings = {
            TipActivationThreshold = 1.0;
            TipButton = binding "AdaptiveBinding" "Binding" "Tip";
            EraserActivationThreshold = 1.0;
            EraserButton = binding "AdaptiveBinding" "Binding" "Eraser";
            # passed through, so the application decides what they do
            PenButtons = [
              (binding "AdaptiveBinding" "Binding" "Button 1")
              (binding "AdaptiveBinding" "Binding" "Button 2")
            ];
            AuxButtons = [
              null # next screen, set by tablet-sync
              # Alt+M / Alt+C are apps.xournalpp's tablet-keys plugin:
              # pen/highlighter toggle and next colour.
              (binding "MultiKeyBinding" "Keys" "Alt+M")
              (binding "MultiKeyBinding" "Keys" "Alt+C")
              (binding "MultiKeyBinding" "Keys" "Control+Z")
            ];
            MouseButtons = [ ];
            MouseScrollUp = null;
            MouseScrollDown = null;
            WheelBindings = [ ];
            DisablePressure = false;
            DisableTilt = false;
            EnableDragBindings = false;
          };
        }
      ];
      LockUsableAreaDisplay = true;
      LockUsableAreaTablet = true;
      Tools = [ ];
    }
  );

  tablet-sync = pkgs.writeShellScriptBin "tablet-sync" ''
    exec ${pkgs.python3}/bin/python3 ${./tablet-sync.py} ${settings} "$@"
  '';
in
{
  options.hardware.drawing-tablet.enable = lib.mkEnableOption "pen tablet via OpenTabletDriver";

  config = lib.mkIf cfg.enable {
    # Gaomon S620 (256c:006f): the kernel only binds hid-generic, which reports
    # the wrong active area. Gaomon's own .deb is X11-only and wants uinput
    # world-writable, so the userspace driver it is.
    hardware.opentabletdriver.enable = true;

    environment.systemPackages = [ tablet-sync ];

    # Owns ~/.config/OpenTabletDriver/settings.json and the screen-* presets:
    # rewrites them at login and on every monitor change, so edits made in
    # otd-gui do not last.
    systemd.user.services.tablet-sync = {
      description = "Map the pen tablet to the connected screens";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "opentabletdriver.service" ];
      path = [
        otd
        pkgs.systemd
      ]
      # asks niri which screen is focused; without it the first screen is used
      ++ lib.optional config.desktop.niri.enable config.programs.niri.package;
      serviceConfig = {
        ExecStart = "${tablet-sync}/bin/tablet-sync --watch";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    home.extraOptions.xdg.configFile."OpenTabletDriver/Plugins/RadialFollow".source = radialFollow;
  };
}
