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
  options.desktop.dms = {
    enable = lib.mkEnableOption "DankMaterialShell (Quickshell bar + panels, blur)";

    initialWallpaper = lib.mkOption {
      type = lib.types.str;
      default = "${../../../assets/wallpaper.jpg}";
      description = ''
        Wallpaper written into session.json when it is first seeded. Only ever
        applies on a fresh seed — afterwards the wallpaper is DMS's to change.
        Its *directory* also becomes the folder DMS cycles through, so point it
        inside a collection to get that for free (see ../wallpapers.nix).
      '';
    };
  };

  # The rest of the module is split across ./theme.nix, ./bar.nix, ./plugins.nix
  # and ./niri.nix (all gated on desktop.dms.enable; their home.extraOptions
  # merge). This file holds the option + core wiring.
  config = lib.mkIf cfg.enable {
    # external-monitor (DDC/CI) brightness: DMS opens /dev/i2c-* directly, so
    # load i2c-dev (creates the nodes + i2c group + udev perms) and add the user
    # to the i2c group so the shell can read/write them.
    hardware.i2c.enable = true;
    # i2c: DDC brightness (above).
    users.users.otis.extraGroups = [
      "i2c"
    ];

    # screen *recording*, CLI only. It used to back the screenCaptureToolbar
    # plugin's record button; quickCapture, which replaced that plugin, only
    # does screenshots, so nothing in the shell drives this any more and there
    # is no keybind for it — `gpu-screen-recorder` is run by hand. Kept because
    # the NixOS module (not just the package) installs the setcap-wrapped
    # binary that capture needs, which a bare systemPackages entry would not.
    # Drop this and ./plugins.nix's note about it if a recorder plugin ever
    # takes the job back.
    programs.gpu-screen-recorder.enable = true;

    services = {
      # backs the power-profile switcher in the battery control-center tile
      # (see bar.nix controlCenterWidgets). No TLP here, so no conflict.
      power-profiles-daemon.enable = true;

      # DMS reads battery presence/charge/AC-online state over UPower's DBus
      # API, not by polling /sys/class/power_supply itself. Without this the
      # battery tile has nothing to query, which is why it showed no battery
      # and defaulted to "plugged in".
      upower.enable = true;

      # the profile picture. DMS asks AccountsService for the user's IconFile
      # (PortalService.getUserProfileImage -> freedesktop.accounts.getUserIconFile)
      # and shows nothing at all when the bus name is missing, which is what a
      # blank avatar looks like. Nothing else here pulls accounts-daemon in — it
      # used to arrive with ReGreet, and went away with it — so enable it
      # explicitly. accountsservice reports ~/.face as the icon when the user has
      # no /var/lib/AccountsService entry, and that file is written below.
      accounts-daemon.enable = true;
    };

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
      # quickCapture. It annotates in-shell and captures through `dms
      # screenshot`, so it needs no external editor (satty, which the
      # screenCaptureToolbar plugin used, went with that plugin) — these are
      # the optional extras its registry entry lists, one feature each.
      # tesseract, the fourth, is already in ../niri/default.nix for the
      # Mod+Ctrl+S OCR bind, and the plugin's OCR button uses the same binary.
      imagemagick # webp/jpeg export, and the crop feeding OCR/QR
      img2pdf # pdf export
      zbar # QR scanning (zbarimg)
      wl-mirror # niriDS (mirror profile)
    ];

    home.extraOptions =
      # `lib` is taken explicitly so it is home-manager's — it carries lib.hm.dag,
      # used by the session-seeding activation below — rather than the NixOS lib
      # this file closes over.
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

          # session.json is deliberately left undeclared. The DMS home module
          # writes it as a read-only store symlink whenever `session != {}`
          # (`xdg.stateFile ... = lib.mkIf (cfg.session != {})`), and a read-only
          # session.json is exactly why DMS could not save a wallpaper picked in
          # its own UI. Wallpaper is runtime state, and the module offers no
          # per-key ownership, so the whole file has to be runtime state.
          #
          # Weather and night mode therefore stop being declarative; they are
          # seeded once below and are yours to change in the DMS settings UI
          # afterwards.
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

        # Seed session.json once, then leave it alone — it is DMS's file to write
        # (the wallpaper, and the settings below once you change them in the UI).
        # Runs when the file is missing *or* is still a store symlink, which is
        # what generations built while `session != {}` left behind; a plain -e
        # test would skip that case and the stale read-only link would survive,
        # leaving DMS still unable to save a wallpaper.
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

              # Starting wallpaper; picking another in DMS overwrites this file.
              # Its directory is also the folder DMS cycles through, so this is
              # how the wallpaper collection gets selected declaratively.
              wallpaperPath = cfg.initialWallpaper;
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
        systemd.user.services.dms.Service = {
          Environment = [
            "NIXPKGS_QT6_QML_IMPORT_PATH=${
              lib.concatMapStringsSep ":" (p: "${p}/lib/qt-6/qml") [
                pkgs.qt6.qtwebsockets
                pkgs.qt6.qtmultimedia
              ]
            }"
          ];

          # systemd's default soft limit is 1024 fds, and the shell settles at
          # ~1010 right after startup — 572 of them eventfds that no longer
          # correspond to anything: `pw-dump` attributes zero graph objects to
          # the quickshell process, so these are PipeWire streams that were set
          # up and torn down without their fds coming back.
          # The next stream then fails to allocate and quickshell dies inside
          # pw_stream_connect:
          #   ERROR: eventfd failed: "Too many open files"
          #    WARN: pw_stream_connect failed "Too many open files"
          #   #4 pw_stream_connect  #10 QRtAudioEngine  #11 QSoundEffect
          # (SIGSEGV, four restarts in five minutes on 2026-08-16). PipeWire
          # clients are expected to need far more than 1024; raise it to the
          # limit systemd already allows as the hard cap.
          LimitNOFILE = 65536;
        };

        # DMS reads the profile image from the AccountsService user icon, which
        # defaults to ~/.face (confirmed via busctl). So just put the avatar
        # there — the daemon that serves it is enabled above.
        home.file.".face".source = ../../../assets/avatar.png;
      };
  };
}
