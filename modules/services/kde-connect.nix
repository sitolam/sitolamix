{ config, lib, ... }:
let
  cfg = config.services.kde-connect;

  # kdeconnect_runcommand has no home-manager option — it's a KDE-app-native
  # config file the plugin reads on its own, keyed by *this device's* local
  # kdeconnect identity (not the phone's). That ID is generated once from
  # privateKey.pem/certificate.pem and only changes if those are deleted, so
  # deviceId is safe to hardcode per host but must be set per host (each
  # machine has its own identity — find it as the UUID directory name under
  # ~/.config/kdeconnect/).
  #
  # The on-disk format is a Qt QByteArray literal holding JSON, itself
  # embedded in an INI string value, hence the escaped quotes:
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
        under ~/.config/kdeconnect/), needed to place the run-command config
        where the KDE Connect Android app expects it. Leave null to skip
        declaring run commands.
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
    # HM module runs kdeconnectd + the tray indicator (DMS has a system tray).
    home.extraOptions.services.kdeconnect = {
      enable = true;
      indicator = true;
    };

    home.extraOptions.xdg.configFile = lib.mkIf (cfg.deviceId != null) {
      "kdeconnect/${cfg.deviceId}/kdeconnect_runcommand/config".text = ''
        [General]
        commands="@ByteArray(${escapedJson})"
      '';
    };

    # the HM module does not open the firewall; KDE Connect needs 1714-1764.
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
