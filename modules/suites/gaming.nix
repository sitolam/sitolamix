{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.suites.gaming;
in
{
  options.suites.gaming.enable = lib.mkEnableOption "Steam + game launchers";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = false;
      gamescopeSession.enable = true;

      # Steam Input synthesises X11 input events through XTEST, which does not
      # exist under a Wayland compositor — so controller-as-keyboard/mouse
      # bindings silently do nothing on niri. extest LD_PRELOADs a shim that
      # turns those calls into uinput events instead. Drop this if Valve ever
      # ships a native Wayland input path.
      extest.enable = true;

      # Wrapped in Steam's own FHS environment, unlike the bare `protontricks`
      # binary this used to install from home.packages — that one cannot see
      # the runtime the prefix was built against and fails on most winetricks
      # verbs.
      protontricks.enable = true;

      # Declarative Proton-GE, so a compatibility tool picked in Steam's UI
      # survives a fresh install of this host. protonup-qt (below) is still
      # around for pulling a *specific* build Steam needs and this pin lacks.
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    programs.gamemode = {
      enable = true;
      # gamemoded can only renice a game above its own priority if the daemon
      # carries CAP_SYS_NICE; without this the `renice` below is requested and
      # then refused, which is the state this config was in.
      enableRenice = true;
      settings.general = {
        renice = 10;
        # RT scheduling for the game's own threads when the CPU has cores to
        # spare — "auto" makes gamemode decide per machine rather than forcing
        # it on the 16 threads of a laptop part.
        softrealtime = "auto";
      };
    };

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          protonup-qt
          lutris
          prismlauncher
          heroic
          gamescope
          # the only way to see whether a game is actually on the GPU; the
          # alternative is reading drm-cycles out of /proc/<pid>/fdinfo by hand.
          mangohud
        ];
      };
  };
}
