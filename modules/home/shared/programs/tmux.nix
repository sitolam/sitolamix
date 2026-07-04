_:
{
  flake.modules.homeManager.shared = {
    programs.tmux = {
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
