{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  scratchpad = inputs.niri-scratchpad.packages.${pkgs.stdenv.hostPlatform.system}.default;
  xwayland-satellite =
    inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.xwayland-satellite-unstable;
in
{
  config = lib.mkIf config.desktop.niri.enable {
    # X11 apps (onlyoffice-desktopeditors and friends) need an X server. niri's
    # built-in integration starts xwayland-satellite itself and — unlike a bare
    # spawn-at-startup — exports DISPLAY to everything niri spawns, so launchers
    # and terminals inherit it too.
    home.extraOptions.programs.niri.settings.xwayland-satellite = {
      enable = true;
      path = lib.getExe xwayland-satellite;
    };

    home.extraOptions.programs.niri.settings.spawn-at-startup = [
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
      # Mod+M scratchpad bind in bindings.nix.
      {
        command = [
          "${scratchpad}/bin/niri-scratchpad"
          "daemon"
        ];
      }
    ];
  };
}
