{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.kanata;

  unit = "kanata-default.service";

  # Both the gamemode hooks and the dankMenu row drive kanata through these,
  # rather than calling systemctl inline, so there is one place that knows the
  # unit name and one place the polkit rule below has to match.
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

    # Home-row mods are tap-hold: every key you hold past the timeout becomes a
    # modifier. That is exactly what holding W to walk or Shift to crouch does,
    # so kanata has to be out of the way while a game has the keyboard.
    #
    # gamemode is the hook because it is the only thing on this machine that
    # already knows a game started and stopped. It only fires for games
    # launched *through* it, so a Steam title needs `gamemoderun %command%` in
    # its launch options — everything else has the dankMenu toggle
    # (trigger.toggle.kanata, ../dms/plugins.nix).
    programs.gamemode.settings.custom = lib.mkIf config.programs.gamemode.enable {
      start = "${kanata-off}/bin/kanata-off";
      end = "${kanata-on}/bin/kanata-on";
    };

    # gamemoded and the shell run as the user, and kanata-default is a *system*
    # unit — without this every game launch and every menu toggle opens a
    # password prompt. Scoped the same way as the winapps rule
    # (../../services/winapps/default.nix): this one unit, these two verbs,
    # this one group. `restart` is deliberately not granted.
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
