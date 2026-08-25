{ config, lib, ... }:
let
  cfg = config.services.printing-suite;
in
{
  options.services.printing-suite.enable = lib.mkEnableOption "CUPS printing with driverless network discovery";

  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;
      # ipp-usb + IPP Everywhere covers modern printers without a vendor
      # driver; drop in a vendor package here (e.g. hplip) if a specific
      # printer needs one.
      drivers = [ ];
    };

    # mDNS/DNS-SD so CUPS' driverless backend can discover IPP printers on
    # the LAN (System Settings -> Printers, or `lpinfo -v`, finds them
    # without typing an IP).
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}
