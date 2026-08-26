# The option is `services.printing-cups`, not `services.printing`: nixpkgs
# already owns `services.printing` (the CUPS module this one configures), so
# a same-named option here would collide with it. Every other module in this
# repo matches its filename -- this is the one deliberate exception.
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
