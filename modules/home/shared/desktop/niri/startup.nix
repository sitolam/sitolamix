_: {
  flake.modules.homeManager.shared = {
    programs.niri.settings.spawn-at-startup = [
      { command = [ "xwayland-satellite" ]; }
      { command = [ "kdeconnectd" ]; }
      { command = [ "wl-clip-persist" "--clipboard" "regular" ]; }
    ];
  };
}
