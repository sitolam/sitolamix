{ config, lib, ... }:
let
  cfg = config.apps.toys;
in
{
  options.apps.toys.enable = lib.mkEnableOption "terminal eye candy (lavat, pipes-rs, peaclock, cava, ...)";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          lavat # `lavat` — ASCII lava lamp, -c <colour> -s <speed>
          pipes-rs # `pipes-rs` — the pipes screensaver, rust rewrite of pipes.sh
          peaclock # `peaclock` — clock/timer/stopwatch, styled from a config file
          tty-clock # `tty-clock -c -C 5` — the classic big-digit centred clock
          cbonsai # `cbonsai -l` — grows a bonsai, live
          cmatrix # `cmatrix -ab` — the green rain
          asciiquarium # `asciiquarium` — fish tank

          # audio visualiser. DMS already pulls cava in for the bar's visualiser
          # widget, so it is on PATH either way — declared here so it survives
          # DMS dropping the dependency, and so `apps.toys` is self-contained.
          cava
        ];
      };
  };
}
