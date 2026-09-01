{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.niri;

  # niri can be told to load any config file at runtime, so practice mode is
  # a config swap and nothing else — no file is edited, and nothing
  # home-manager owns is touched.
  practice-mode = pkgs.writeShellApplication {
    name = "practice-mode";
    runtimeInputs = [ pkgs.niri-unstable ]; # `niri msg`
    text = builtins.readFile ./_lib/practice-mode.sh;
  };
in
{
  options.desktop.niri.practiceCommand = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = lib.getExe practice-mode;
    description = ''
      Path to the practice-mode script, for modules that want to run
      something with niri's keybinds switched off — see apps.keydrill.

      Known upstream bug (niri-wm/niri#4515): after enough on/off toggles
      accumulate in one compositor session, `load-config-file` can stop
      actually clearing a removed keybind — it still fires even though the
      just-loaded config has no such bind, and no error is logged. Reloading
      again does not clear it; only a fresh niri session does. Nothing to fix
      here until upstream does — drop this paragraph once #4515 closes.
    '';
  };

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      hm@{ pkgs, ... }:
      let
        # This flake's own config with the binds section replaced by the
        # single bind that swaps back. Everything else — layout, input,
        # window rules, environment — carries over unchanged, so practice
        # mode does not visibly rearrange the desktop.
        #
        # Stripping the block textually rather than re-rendering it from Nix
        # is what keeps this out of an infinite recursion: the bind below
        # spawns the script, and the script finds this file by path at
        # runtime, so nothing in `binds` depends on this derivation.
        # `niri validate` runs at build time, so a bad strip fails the build
        # rather than the session.
        practiceConfig = pkgs.runCommand "niri-practice-config.kdl" { } ''
          awk '
            /^binds \{/        { skip = 1 }
            skip == 0          { print }
            skip == 1 && /^\}/ { skip = 0 }
          ' ${pkgs.writeText "niri-config.kdl" hm.config.programs.niri.finalConfig} > $out

          cat >> $out <<EOF

          // DMS owns display config and writes it to niri/dms/outputs.kdl,
          // which the real config.kdl includes (see ../dms/niri.nix).
          // practice.kdl replaces config.kdl wholesale, so it has to include
          // that too or the monitors rearrange for as long as practice mode
          // is on. Absolute, because niri resolves a relative include against
          // the including file — and this one lives in the store.
          include optional=true "${hm.config.home.homeDirectory}/.config/niri/dms/outputs.kdl"

          binds {
              Mod+Shift+Escape allow-inhibiting=false { spawn "${cfg.practiceCommand}" "off"; }
          }
          EOF

          ${lib.getExe pkgs.niri-unstable} validate -c $out
        '';
      in
      {
        home.packages = [ practice-mode ];

        xdg.configFile."niri/practice.kdl".source = practiceConfig;

        # Mod+Escape is a different thing and cannot do this: it toggles the
        # Wayland keyboard-shortcuts-inhibit protocol, which only works for a
        # client that registered an inhibitor. niri looks the focused surface
        # up in keyboard_shortcuts_inhibiting_surfaces and does nothing when
        # it is absent, and terminals do not ask.
        #
        # This bind is also the one bind practice.kdl keeps, so the same key
        # both enters and leaves — you cannot strand yourself with no binds.
        programs.niri.settings.binds."Mod+Shift+Escape" = {
          allow-inhibiting = false;
          action.spawn = [
            cfg.practiceCommand
            "toggle"
          ];
        };
      };
  };
}
