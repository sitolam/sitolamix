{ config, lib, ... }:
let
  cfg = config.apps.tmux;
in
{
  options.apps.tmux.enable = lib.mkEnableOption "tmux";

  config = lib.mkIf cfg.enable {
    home.extraOptions.programs.tmux = {
      enable = true;
      clock24 = true;
      keyMode = "vi";
      shortcut = "a";
      terminal = "screen-256color";
      historyLimit = 50000;

      extraConfig = ''
        set -g mouse on
        set -g focus-events on
        set -sg escape-time 10
      '';
    };
  };
}
