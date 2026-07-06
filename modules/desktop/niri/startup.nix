{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  scratchpad = inputs.niri-scratchpad.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  config = lib.mkIf config.desktop.niri.enable {
    home.extraOptions.programs.niri.settings.spawn-at-startup = [
      { command = [ "xwayland-satellite" ]; }
      { command = [ "kdeconnectd" ]; }
      {
        command = [
          "wl-clip-persist"
          "--clipboard"
          "regular"
        ];
      }
      # heyoeyo/niri_tweaks: make niri auto-tile while there are fewer than N
      # windows open (stdlib-only python, talks to niri IPC via $NIRI_SOCKET).
      {
        command = [
          "${pkgs.python3}/bin/python3"
          "${inputs.niri-tweaks}/niri_tile_to_n.py"
        ];
      }
      # niri-scratchpad-rs daemon: backs the dynamic registers used by the
      # Mod+M (stash) / Mod+S (show) binds in bindings.nix.
      {
        command = [
          "${scratchpad}/bin/niri-scratchpad"
          "daemon"
        ];
      }
    ];
  };
}
