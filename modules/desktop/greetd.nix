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
  # the module only does anything once programs.dms-greeter.enable is set, so
  # importing it unconditionally is safe (imports can't sit under an mkIf).
  imports = [ inputs.dank-greeter.nixosModules.default ];

  options.desktop.greetd.enable = lib.mkEnableOption "greetd + DMS Greeter (DankMaterialShell login screen)";

  config = lib.mkIf cfg.enable {
    programs.dms-greeter = {
      enable = true; # implies services.greetd.enable (mkDefault in their module)

      # dms-greeter is a launcher: it starts this compositor itself and writes
      # the greeter's config for it, so the greeter runs under the same niri
      # build as the session (it reads programs.niri.package, set in niri/).
      #
      # This is also why the old ReGreet-in-cage single-output workaround
      # ("-m last", so the login box didn't land on the bezel) is gone: niri
      # drives the outputs and the greeter draws per-output like the DMS lock
      # screen does.
      compositor.name = "niri";

      # theme sync. greetd's preStart copies DMS's settings.json, session.json
      # and dms-colors.json out of this home into /var/lib/dms-greeter, plus
      # whatever wallpaper session.json points at, so the login screen matches
      # the desktop. It is a copy taken at greetd start: changing the theme
      # shows up on the login screen after the next reboot or
      # `systemctl restart greetd`, not immediately.
      configHome = config.users.users.otis.home;
    };
  };
}
