{ config, lib, ... }:
let
  cfg = config.services.kde-connect;
in
{
  options.services.kde-connect.enable = lib.mkEnableOption "KDE Connect (phone integration)";

  config = lib.mkIf cfg.enable {
    # HM module runs kdeconnectd + the tray indicator (DMS has a system tray).
    home.extraOptions.services.kdeconnect = {
      enable = true;
      indicator = true;
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
