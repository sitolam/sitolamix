{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.niri;

  # niri can load any config file at runtime, so practice mode is just a
  # config swap — no file edited, nothing home-manager owns is touched.
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
    '';
  };

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      hm@{ pkgs, ... }:
      let
        # This flake's config with the binds section replaced by the single
        # bind that swaps back; everything else carries over unchanged.
        # Stripped textually rather than re-rendered from Nix to avoid
        # infinite recursion (the bind spawns a script that finds this file
        # by path at runtime, so `binds` never depends on this derivation).
        # `niri validate` runs at build time, so a bad strip fails the build.
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

          // recent-windows (Alt/Mod+Tab) is a separate hardcoded-default
          // section, not part of \`binds\` above — niri-wm/niri#4515. Absent
          // from config means ON with its own Mod+Tab binding, which is
          // exactly the key practice mode exists to free up.
          recent-windows { off; }

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

        # Mod+Escape can't substitute: it toggles the Wayland
        # keyboard-shortcuts-inhibit protocol, which only works for a client
        # that registered an inhibitor, and terminals don't.
        #
        # This is also the one bind practice.kdl keeps, so the same key
        # both enters and leaves — you can't strand yourself with no binds.
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
