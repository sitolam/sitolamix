{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.suites.gaming;

  # gamemode's `custom.start`/`custom.end` are two single strings, so exactly
  # one module can define them. Several want a hook (kanata's home-row mods,
  # the power profile below), hence this list: modules append to
  # `suites.gaming.gamemodeHooks.*` and this file is the only place that
  # writes gamemode's own option.
  hook =
    name: lines:
    "${pkgs.writeShellScript "gamemode-${name}" ''
      profile_state="''${XDG_RUNTIME_DIR:-/tmp}/gamemode-power-profile"
      ${lib.concatStringsSep "\n" lines}
    ''}";

  ppdctl = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl";
in
{
  options.suites.gaming = {
    enable = lib.mkEnableOption "Steam + game launchers";

    gamemodeHooks = {
      start = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Shell lines to run when gamemode is entered.";
      };
      end = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Shell lines to run when gamemode is left.";
      };
    };
  };

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

      settings = {
        general = {
          renice = 10;

          # Deliberately no softrealtime here. It asks for SCHED_ISO, which no
          # upstream kernel implements (gamemode's own shipped gamemode.ini
          # says so) — it was set to "auto" and did nothing on either host.
          # Revisit if a kernel this flake pins ever grows the policy.

          # Deliberately no igpu_power_threshold override here. gamemode's
          # iGPU heuristic (swap the governor to igpu_desiredgov=powersave
          # once iGPU/CPU power passes the threshold) reads RAPL energy from
          # /sys/class/powercap/intel-rapl/…/energy_uj, which is 0400 root
          # since the PLATYPUS mitigations. gamemoded runs as the user, so
          # the read fails, the optimisation never enables, and the setting
          # would be a no-op — on omnibook and on gamingpc alike. Revisit
          # only if those files ever become group-readable.
        };

        custom = {
          start = hook "start" cfg.gamemodeHooks.start;
          end = hook "end" cfg.gamemodeHooks.end;
        };
      };
    };

    # `renice` and core parking are refused unless the calling user is in the
    # gamemode group — gamemoded carrying CAP_SYS_NICE (enableRenice above) is
    # only half of it, and nixpkgs' module creates the group without putting
    # anyone in it. Takes effect on next login, not on the rebuild.
    users.users.otis.extraGroups = [ "gamemode" ];

    # Sustained clocks are capped by the platform profile, which gamemode has
    # no notion of — it only drives the cpufreq governor. On a laptop
    # "balanced" is a real power limit (PL1) and the iGPU is the first thing
    # clipped by it. Raise it for the length of the game only; leaving the
    # machine on "performance" costs battery and fan noise all day.
    # power-profiles-daemon is enabled in modules/desktop/dms/default.nix.
    #
    # The previous profile is saved rather than assumed, so quitting a game
    # that was started on battery does not silently promote the machine from
    # power-saver to balanced. Every call is `|| true`: a PPD that is not
    # running must not stop a game from launching, or stop the rest of the
    # end hook from running.
    suites.gaming.gamemodeHooks = {
      start = [
        ''
          ${ppdctl} get > "$profile_state" 2>/dev/null || true
          ${ppdctl} set performance || true
        ''
      ];
      end = [
        ''
          ${ppdctl} set "$(cat "$profile_state" 2>/dev/null || echo balanced)" || true
          rm -f "$profile_state"
        ''
      ];
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
