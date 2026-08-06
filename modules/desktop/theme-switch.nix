{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.theming.stylix;
  themes = import ../../themes { inherit lib; };

  # Every theme except the active one. The active theme *is* the base
  # configuration, so a specialisation of it would be a second identical closure.
  alternates = removeAttrs themes.themes [ cfg.theme ];

  # Switching runs against the *system profile*, never /run/current-system.
  # Specialisations are not recursive: once you have switched into one,
  # /run/current-system is that specialisation and no longer contains a
  # specialisation/ directory, so a second switch would have nowhere to look. The
  # profile keeps pointing at the parent generation, which holds all of them.
  profile = "/nix/var/nix/profiles/system";
  switchTo = name: "${profile}/specialisation/${name}/bin/switch-to-configuration";
  switchToBase = "${profile}/bin/switch-to-configuration";

  themeSwitch = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.systemd
    ];
    text = ''
      base=${lib.escapeShellArg cfg.theme}
      known=(${lib.escapeShellArgs themes.names})

      usage() {
        echo "usage: theme <name>"
        echo "themes: ''${known[*]}"
        echo "current: $(cat /etc/theme-name 2>/dev/null || echo unknown)"
      }

      [ $# -eq 1 ] || { usage; exit 2; }
      case " ''${known[*]} " in
        *" $1 "*) ;;
        *) echo "unknown theme: $1" >&2; usage >&2; exit 2 ;;
      esac

      if [ "$1" = "$base" ]; then
        target=${lib.escapeShellArg switchToBase}
      else
        target="${profile}/specialisation/$1/bin/switch-to-configuration"
      fi

      if [ ! -x "$target" ]; then
        notify-send --app-name=theme --icon=preferences-desktop-theme \
          "Theme $1 unavailable" "$target is missing — rebuild first"
        exit 1
      fi

      # switch-to-configuration needs root; the sudoers rule below makes exactly
      # these two command paths password-free.
      if sudo -n "$target" switch >/dev/null 2>&1; then
        notify-send --app-name=theme --icon=preferences-desktop-theme \
          "Theme: $1" "already-open terminals keep their old colours"
      else
        notify-send --app-name=theme --icon=dialog-error \
          "Theme switch failed" "$1 — see: journalctl -e"
        exit 1
      fi
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    # One prebuilt system per alternate theme. Switching is an activation of an
    # existing closure — seconds, no rebuild and no eval. They also show up as
    # boot entries, which is the only way a theme choice survives a reboot:
    # switch-to-configuration does not change the boot default.
    specialisation = lib.mapAttrs (name: _: {
      configuration.theming.stylix.theme = lib.mkForce name;
    }) alternates;

    # Lets `theme` report what is running. /etc is swapped by activation, so this
    # tracks the active specialisation rather than the booted generation.
    environment.etc."theme-name".text = cfg.theme;

    security.sudo.extraRules = [
      {
        users = [ "otis" ];
        commands = [
          # A `*` in sudoers does not match `/`, so this wildcard is confined to
          # one path component, and the profile is a root-owned symlink the user
          # cannot repoint. This grants nothing new in practice: `trusted-users =
          # otis` in modules/system/nix.nix is already root-equivalent.
          {
            command = "${profile}/specialisation/*/bin/switch-to-configuration switch";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${switchToBase} switch";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    home.extraOptions = {
      home.packages = [ themeSwitch ];

      # One launcher entry per theme, so Mod+Space -> "theme" lists them all.
      # NoDisplay keeps them out of the applications menu proper.
      xdg.desktopEntries = lib.mapAttrs' (
        name: _:
        lib.nameValuePair "theme-${name}" {
          name = "Theme: ${name}";
          comment = "Switch the system colour scheme to ${name}";
          exec = "theme ${name}";
          icon = "preferences-desktop-theme";
          terminal = false;
          categories = [ "Settings" ];
        }
      ) themes.themes;
    };
  };
}
