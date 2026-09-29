# Named `services.printing-cups`, not `services.printing`: nixpkgs already
# owns that option name (the CUPS module this one configures).
{ config, lib, ... }:
let
  cfg = config.services.printing-cups;
in
{
  options.services.printing-cups.enable = lib.mkEnableOption "CUPS printing with driverless network discovery";

  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;
      # ipp-usb + IPP Everywhere covers modern printers without a vendor
      # driver; add one here (e.g. hplip) if a specific printer needs it.
      drivers = [ ];
    };

    # mDNS/DNS-SD so CUPS' driverless backend can discover IPP printers on
    # the LAN.
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}
