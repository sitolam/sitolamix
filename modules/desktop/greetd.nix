{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.desktop.greetd;
in
{
  # Safe to import unconditionally: the module only acts once
  # programs.dms-greeter.enable is set (imports can't sit under an mkIf).
  imports = [ inputs.dank-greeter.nixosModules.default ];

  options.desktop.greetd.enable = lib.mkEnableOption "greetd + DMS Greeter (DankMaterialShell login screen)";

  config = lib.mkIf cfg.enable {
    programs.dms-greeter = {
      enable = true; # implies services.greetd.enable (mkDefault in their module)

      # dms-greeter starts its own niri (reading programs.niri.package from
      # niri/) and writes that compositor's config, so the greeter runs the
      # same niri build as the session and draws per-output like the lock
      # screen does.
      compositor.name = "niri";

      # greetd's preStart copies DMS's settings.json, session.json and
      # dms-colors.json from this home into /var/lib/dms-greeter so the login
      # screen matches the desktop theme. It's a copy taken at greetd start,
      # so a theme change only shows up after the next reboot or
      # `systemctl restart greetd`.
      configHome = config.users.users.otis.home;
    };
  };
}
