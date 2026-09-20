{ config, lib, ... }:
let
  cfg = config.apps.oop-apps;
in
{
  options.apps.oop-apps.enable = lib.mkEnableOption "BlueJ/Greenfoot OOP course apps";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          jdk25 # course requires Java >= 21; jdk25 is latest LTS-track release
          # Unstable's bluej/greenfoot pull an openjdk21 that builds openjfx's
          # web module from source and fails (`perl` exits 1 in
          # :web:compileNativeLinux). Stable's build is cached, so pin these
          # two to pkgs.stable until unstable's openjfx build is fixed.
          stable.bluej # course requires >= 5.5.0
          stable.greenfoot # course requires >= 3.9.0
        ];
      };
  };
}
