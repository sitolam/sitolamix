{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.kanata;

  unit = "kanata-default.service";

  # Gamemode hooks and the dankMenu row both drive kanata through these
  # wrappers, so there's one place that knows the unit name and one place
  # the polkit rule below has to match.
  kanata-off = pkgs.writeShellScriptBin "kanata-off" ''
    exec ${pkgs.systemd}/bin/systemctl stop ${unit}
  '';
  kanata-on = pkgs.writeShellScriptBin "kanata-on" ''
    exec ${pkgs.systemd}/bin/systemctl start ${unit}
  '';
  kanata-toggle = pkgs.writeShellScriptBin "kanata-toggle" ''
    if ${pkgs.systemd}/bin/systemctl is-active --quiet ${unit}; then
      exec ${kanata-off}/bin/kanata-off
    else
      exec ${kanata-on}/bin/kanata-on
    fi
  '';
in
{
  options.desktop.kanata.enable = lib.mkEnableOption "kanata home-row-mods keyboard remapping";

  config = lib.mkIf cfg.enable {
    services.kanata = {
      enable = true;
      keyboards.default = {
        devices = [ ];
        extraDefCfg = ''
          log-layer-changes no
          process-unmapped-keys yes
          concurrent-tap-hold yes
        '';
        config = builtins.readFile ./config.kbd;
      };
    };

    environment.systemPackages = [
      kanata-off
      kanata-on
      kanata-toggle
    ];

    # Home-row mods are tap-hold, which collides with holding W to walk or
    # Shift to crouch, so kanata must step aside while a game has the
    # keyboard. gamemode is the hook since it already knows when a game
    # starts/stops, but only fires for games launched *through* it — a Steam
    # title needs `gamemoderun %command%`; everything else uses the dankMenu
    # toggle (trigger.toggle.kanata, ../dms/plugins.nix).
    #
    # gamemode's custom.start/end are pooled in modules/suites/gaming.nix
    # since more than one module wants them — append here, don't set
    # programs.gamemode.settings.custom directly.
    suites.gaming.gamemodeHooks = lib.mkIf config.programs.gamemode.enable {
      start = [ "${kanata-off}/bin/kanata-off" ];
      end = [ "${kanata-on}/bin/kanata-on" ];
    };

    # Without this, every game launch and menu toggle would prompt for a
    # password (gamemoded/the shell run as the user, kanata-default is a
    # *system* unit). Scoped like the winapps rule
    # (../../services/winapps/default.nix): this unit, these two verbs, this
    # group only — `restart` is deliberately not granted.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "${unit}" &&
            (action.lookup("verb") == "start" || action.lookup("verb") == "stop") &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
