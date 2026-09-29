{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.suites.gaming;

  # gamemode's custom.start/end are single strings; others append to
  # suites.gaming.gamemodeHooks.* instead of writing gamemode's option directly.
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

      # Steam Input's XTEST controller bindings do nothing under Wayland;
      # extest LD_PRELOADs a uinput shim instead. Drop once Valve ships native Wayland input.
      extest.enable = true;

      # Wrapped in Steam's FHS env, unlike a bare protontricks package, which
      # can't see the runtime the prefix was built against.
      protontricks.enable = true;

      # Declarative Proton-GE so it survives a fresh install; protonup-qt
      # (below) still covers pulling a specific build Steam needs.
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    programs.gamemode = {
      enable = true;
      # Without this, gamemoded can't renice above its own priority.
      enableRenice = true;

      settings = {
        general = {
          renice = 10;

          # No softrealtime: asks for SCHED_ISO, unimplemented upstream.
          # No igpu_power_threshold: needs RAPL energy files that are 0400
          # root since the PLATYPUS mitigations, unreadable by the user daemon.
        };

        custom = {
          start = hook "start" cfg.gamemodeHooks.start;
          end = hook "end" cfg.gamemodeHooks.end;
        };
      };
    };

    # nixpkgs' gamemode module creates the group without populating it.
    # Takes effect on next login, not on rebuild.
    users.users.otis.extraGroups = [ "gamemode" ];

    # gamemode only drives cpufreq; sustained clocks are capped by the power
    # profile, so raise it to performance and restore the saved one after.
    # Every call is `|| true`: a PPD that isn't running must not block the game.
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
          mangohud # shows whether a game is actually running on the GPU
        ];
      };
  };
}
