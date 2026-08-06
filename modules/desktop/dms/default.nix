{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.desktop.dms;
in
{
  options.desktop.dms.enable = lib.mkEnableOption "DankMaterialShell (Quickshell bar + panels, blur)";

  # The rest of the module is split across ./theme.nix, ./bar.nix, ./plugins.nix
  # and ./niri.nix (all gated on desktop.dms.enable; their home.extraOptions
  # merge). This file holds the option + core wiring.
  config = lib.mkIf cfg.enable {
    # external-monitor (DDC/CI) brightness: DMS opens /dev/i2c-* directly, so
    # load i2c-dev (creates the nodes + i2c group + udev perms) and add the user
    # to the i2c group so the shell can read/write them.
    hardware.i2c.enable = true;
    # i2c: DDC brightness (above). input: typingSounds reads /dev/input/event*.
    users.users.otis.extraGroups = [
      "i2c"
      "input"
    ];

    # screen *recording* for the screenCaptureToolbar plugin. The NixOS module
    # (not just the package) installs the setcap-wrapped binary gpu-screen-recorder
    # needs to capture; screenshots themselves use grim/slurp/satty.
    programs.gpu-screen-recorder.enable = true;

    # backs the power-profile switcher in the battery control-center tile
    # (see bar.nix controlCenterWidgets). No TLP here, so no conflict.
    services.power-profiles-daemon.enable = true;

    # runtime deps the enabled DMS plugins shell out to (registry ships only the
    # plugin source). nix dedups any already present (mpv/udisks/util-linux/...).
    environment.systemPackages = with pkgs; [
      jq
      curl
      cliphist # clipboardplus
      socat # ambient-sound
      mpv # ambient-sound
      parted # usb-manager
      dosfstools # usb-manager
      e2fsprogs # usb-manager
      exfatprogs # usb-manager
      udisks # usb-manager
      util-linux # usb-manager (lsblk)
      satty # screenCaptureToolbar (annotation editor; grim/slurp/wl-clipboard via niri, gpu-screen-recorder via media suite)
      evtest # typingSounds (read key events)
      libinput # typingSounds
      ffmpeg # typingSounds (sound playback)
    ];

    home.extraOptions =
      # `lib` is taken explicitly so it is home-manager's (which carries
      # lib.hm.dag, used by the session-seeding activation below) rather than the
      # NixOS lib this file closes over.
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        imports = [
          inputs.dms.homeModules.dank-material-shell
          inputs.dms.homeModules.niri
          # declares programs.dank-material-shell.plugins.<id> (enable=false + a
          # pinned src) for every registry plugin; we flip on the ones we want.
          inputs.dms-plugin-registry.homeModules.default
        ];

        programs.dank-material-shell = {
          enable = true;
          systemd.enable = true;

          # use the cached nixpkgs builds rather than the flake input building
          # dms-shell + quickshell from source. (dgop already defaults to pkgs.)
          #
          # ...patched so the power menu picks options by NUMBER (the badge shows
          # the row's position, 1..N top-to-bottom, and pressing that digit picks
          # it). DMS hard-codes per-action letter shortcuts (R/X/P/L/S/H/D) with
          # no setting to change them; rather than remap letter->letter (which
          # scrambles the numbers vs the on-screen order, since the order is just
          # SettingsData.powerMenuActions), drive the badge + key handling off the
          # delegate index so it's always sequential regardless of order. The old
          # letter shortcuts keep working as a bonus. Pinned to the current DMS
          # layout: a version bump that moves these lines trips --replace-fail and
          # fails the build loudly, which is the cue to refresh the patch.
          package = pkgs.dms-shell.overrideAttrs (old: {
            postFixup = (old.postFixup or "") + ''
              substituteInPlace $out/share/quickshell/dms/Modals/PowerMenuModal.qml \
                --replace-fail 'text: gridButtonRect.actionData.key' 'text: (gridButtonRect.index + 1)' \
                --replace-fail 'text: listButtonRect.actionData.key' 'text: (listButtonRect.index + 1)' \
                --replace-fail '(event.key === Qt.Key_P && !(event.modifiers & Qt.ControlModifier))) {' '(event.key === Qt.Key_P && !(event.modifiers & Qt.ControlModifier)) || (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && !(event.modifiers & Qt.ControlModifier))) {' \
                --replace-fail 'switch (event.key) {' 'if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && !(event.modifiers & Qt.ControlModifier)) { const numIndex = event.key - Qt.Key_1; if (numIndex < visibleActions.length) { startHold(getActionAtIndex(numIndex), numIndex); event.accepted = true; return; } } switch (event.key) {'
            '';
          });
          quickshell.package = pkgs.quickshell;

          # matugen would regenerate app color files from DMS's palette and fight
          # stylix; keep stylix authoritative for every app but DMS's own shell.
          enableDynamicTheming = false;

          # session.json is deliberately NOT declared. The DMS home module writes
          # it as a read-only store symlink whenever `session != {}`
          # (`xdg.stateFile ... = lib.mkIf (cfg.session != {})`), and a read-only
          # session.json means DMS cannot save a wallpaper you pick in its own
          # UI. Wallpaper is runtime state, so the whole file has to be runtime
          # state — the module offers no per-key ownership.
          #
          # Weather and night mode used to live here; they are seeded once
          # instead (see the activation script below) and are afterwards yours to
          # change in the DMS settings UI.
          session = { };
        };

        # DMS only reads its settings at startup, and the systemd user service's
        # unit doesn't change when only settings.json/the theme file change — so
        # nothing restarts it on rebuild. Trigger a restart (via sd-switch) when
        # the generated settings.json changes, so theme/blur edits take effect
        # after `nixos-rebuild switch` without a manual restart or relogin.
        systemd.user.services.dms.Unit.X-Restart-Triggers = [
          config.xdg.configFile."DankMaterialShell/settings.json".source
        ];

        # Seed session.json once, then never touch it again — it is DMS's to
        # write (wallpaper, and the settings below once you change them in the
        # UI). Runs when the file is missing *or* still a store symlink, which is
        # what a generation built before session.json was unmanaged left behind;
        # without the -L case the stale read-only symlink would survive and DMS
        # would still be unable to save a wallpaper.
        home.activation.seedDmsSession =
          let
            seed = (pkgs.formats.json { }).generate "dms-session-seed.json" {
              weatherLocation = "Eeklo, 9900";
              weatherCoordinates = "51.2,3.6";

              nightModeEnabled = true;
              nightModeAutoEnabled = true;
              nightModeAutoMode = "location";
              nightModeUseIPLocation = true;
              nightModeTemperature = 5000;
              nightModeHighTemperature = 6500;

              # starting wallpaper; changing it in DMS overwrites this file.
              wallpaperPath = "${../../../assets/wallpaper.jpg}";
            };
          in
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            state="$HOME/.local/state/DankMaterialShell/session.json"
            if [ ! -e "$state" ] || [ -L "$state" ]; then
              run mkdir -p "$(dirname "$state")"
              run rm -f "$state"
              # install, not cp: store files are read-only and DMS must write it.
              run install -m 644 ${seed} "$state"
            fi
          '';

        # Some plugins import Qt QML modules quickshell doesn't bundle:
        #   QtWebSockets — homeAssistantMonitor
        #   QtMultimedia — mouthGuard (SoundEffect alert sounds)
        # Add them to the shell's QML path (the quickshell wrapper *prefixes*
        # NIXPKGS_QT6_QML_IMPORT_PATH, so this value survives).
        systemd.user.services.dms.Service.Environment = [
          "NIXPKGS_QT6_QML_IMPORT_PATH=${
            lib.concatMapStringsSep ":" (p: "${p}/lib/qt-6/qml") [
              pkgs.qt6.qtwebsockets
              pkgs.qt6.qtmultimedia
            ]
          }"
        ];

        # DMS reads the profile image from the AccountsService user icon, which
        # defaults to ~/.face (confirmed via busctl). So just put the avatar
        # there — no AccountsService plumbing needed.
        home.file.".face".source = ../../../assets/avatar.png;
      };
  };
}
