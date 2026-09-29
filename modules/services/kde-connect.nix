{ config, lib, ... }:
let
  cfg = config.services.kde-connect;

  # kdeconnect_runcommand has no home-manager option — it's a KDE-app-native
  # config file, keyed by this device's own kdeconnect identity (not the
  # phone's), so deviceId must be set per host. On-disk format is a Qt
  # QByteArray literal holding JSON, itself embedded in an INI string value,
  # hence the escaped quotes:
  #   commands="@ByteArray({\"<uuid>\":{\"command\":\"...\",\"name\":\"...\"}})"
  commandsJson = builtins.toJSON (
    lib.mapAttrs' (name: command: {
      name = builtins.hashString "md5" name;
      value = { inherit name command; };
    }) cfg.commands
  );
  escapedJson = lib.replaceStrings [ "\"" ] [ "\\\"" ] commandsJson;
in
{
  options.services.kde-connect = {
    enable = lib.mkEnableOption "KDE Connect (phone integration)";

    deviceId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        This machine's own kdeconnect device ID (the UUID directory name
        under ~/.config/kdeconnect/). Leave null to skip declaring run
        commands.
      '';
    };

    commands = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "Lock Screen" = "loginctl lock-session";
      };
      description = "Remote commands exposed to paired phones via the run-command plugin.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, lib, ... }:
      {
        services.kdeconnect = {
          enable = true;
          indicator = true;
        };

        xdg.configFile = lib.mkIf (cfg.deviceId != null) {
          "kdeconnect/${cfg.deviceId}/kdeconnect_runcommand/config".text = ''
            [General]
            commands="@ByteArray(${escapedJson})"
          '';
        };

        # "Send via KDE Connect" in Nautilus's right-click menu. The extension
        # ships in kdeconnect-kde but nautilus-python never scans the
        # per-user profile's XDG_DATA_DIRS, only ~/.local/share, so link it
        # there by hand. Drop if nixpkgs ever wraps nautilus with that dir.
        home.file.".local/share/nautilus-python/extensions/kdeconnect-share.py".source =
          lib.mkIf config.apps.nautilus.enable "${pkgs.kdePackages.kdeconnect-kde}/share/nautilus-python/extensions/kdeconnect-share.py";
      };

    # HM module doesn't open the firewall; KDE Connect needs 1714-1764.
    networking.firewall = {
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
    };
  };
}
