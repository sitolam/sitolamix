{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.desktop.dux-shell;
in
{
  options.desktop.dux-shell = {
    enable = lib.mkEnableOption "Dux Shell, formerly DankMaterialShell (Quickshell bar + panels, blur)";

    initialWallpaper = lib.mkOption {
      type = lib.types.str;
      default = "${../../../assets/wallpaper.jpg}";
      description = ''
        Wallpaper written into session.json on first seed only; DMS owns it
        afterwards. Its directory is also the folder DMS cycles through.
      '';
    };
  };

  # Split across sibling files (theme, bar, plugins, niri), all gated on
  # desktop.dux-shell.enable; this file holds the option + core wiring.
  config = lib.mkIf cfg.enable {
    # DMS opens /dev/i2c-* directly for DDC monitor brightness.
    hardware.i2c.enable = true;
    users.users.otis.extraGroups = [
      "i2c"
    ];

    # CLI screen recording; quickCapture replaced the plugin that drove
    # this, so nothing calls it now — run by hand. Kept for the
    # setcap-wrapped binary capture needs.
    programs.gpu-screen-recorder.enable = true;

    services = {
      # power-profile switcher in the battery control-center tile (bar.nix).
      power-profiles-daemon.enable = true;

      # DMS reads battery state over UPower's DBus API; without this the
      # tile shows nothing.
      upower.enable = true;

      # DMS shows a blank avatar without AccountsService; it falls back to
      # ~/.face (written below) when there's no entry.
      accounts-daemon.enable = true;
    };

    # Runtime deps the enabled plugins shell out to; the registry ships
    # only source.
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
      # quickCapture's optional extras, one per feature; tesseract already
      # comes from the OCR keybind elsewhere.
      imagemagick # webp/jpeg export, and the crop feeding OCR/QR
      img2pdf # pdf export
      zbar # QR scanning (zbarimg)
      wl-mirror # niriDS (mirror profile)
    ];

    home.extraOptions =
      # `lib` here is home-manager's (carries lib.hm.dag for the activation
      # below), not the NixOS lib this file otherwise closes over.
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        imports = [
          # Upstream kept the pre-rename option names (programs.dank-material-shell).
          inputs.dux-shell.homeModules.dank-material-shell
          inputs.dux-shell.homeModules.niri
          # declares plugins.<id> (enable=false + pinned src) for every
          # registry plugin; flipped on below.
          inputs.dux-plugin-registry.homeModules.default
        ];

        programs.dank-material-shell = {
          enable = true;
          systemd.enable = true;
          # khal-backed events in the clock popout; no khal calendars are set
          # up here, and hoshiCalendar (plugins.nix) reads the .ics feeds.
          enableCalendarEvents = false;
          # The flake's own build, so `nix flake update dux-shell` is the whole
          # upgrade. One patch: the dock's launcher button opens dankMenu
          # (plugins.nix) instead of spotlight, falling back to spotlight if
          # dankMenu isn't loaded. Drop once upstream has an option for it
          # (duxlabs-dev/dux-shell#3908); the QML is copied in postInstall, so
          # `patches` can't reach it.
          package =
            inputs.dux-shell.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell.overrideAttrs
              (old: {
                postInstall = old.postInstall + ''
                  substituteInPlace $out/share/quickshell/dms/Modules/Dock/DockLauncherButton.qml \
                    --replace-fail 'PopoutService.toggleDankLauncherV2();' \
                      'const menu = PluginService.pluginDaemonInstances["dankMenu"]; if (!menu) return PopoutService.toggleDankLauncherV2(); menu.menuVisible ? menu.closeMenu() : menu.openAt("root");'
                '';
              });

          # Deliberately undeclared: the DMS home module writes session.json
          # as a read-only store symlink whenever `session != {}`, breaking
          # DMS's own wallpaper save. Weather/night mode are seeded once below instead.
          session = { };
        };

        # Nothing restarts dms when only settings.json/the theme file
        # changes. Trigger one via sd-switch so edits apply after switch
        # without relogin.
        systemd.user.services.dms.Unit.X-Restart-Triggers = [
          config.xdg.configFile."dms/settings.json".source
        ];

        # Seed session.json once, then leave it to DMS. Runs when missing or
        # still a store symlink (left by session != {} generations) — a
        # plain -e check would miss the symlink case. Skipped while a
        # pre-2.0 DankMaterialShell/session.json exists: `dms run` moves that
        # dir to dms/ itself, and a seed here would shadow the live file.
        home.activation.seedDmsSession =
          let
            seed = (pkgs.formats.json { }).generate "dms-session-seed.json" {
              weatherLocation = "Eeklo, 9900";
              weatherCoordinates = "51.2,3.6";

              isLightMode = false; # matugen templates here only render dark tokens

              nightModeEnabled = true;
              nightModeAutoEnabled = true;
              nightModeAutoMode = "location";
              nightModeUseIPLocation = true;
              nightModeTemperature = 5000;
              nightModeHighTemperature = 6500;

              # Starting wallpaper; picking another in DMS overwrites this file.
              wallpaperPath = cfg.initialWallpaper;
            };
          in
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            state="$HOME/.local/state/dms/session.json"
            legacy="$HOME/.local/state/DankMaterialShell/session.json"
            if [ -f "$legacy" ] && [ ! -L "$legacy" ] && [ ! -e "$state" ]; then
              : # left for DMS's own legacy-dir migration
            elif [ ! -e "$state" ] || [ -L "$state" ]; then
              run mkdir -p "$(dirname "$state")"
              run rm -f "$state"
              # install, not cp: store files are read-only and DMS must write it.
              run install -m 644 ${seed} "$state"
            else
              # A wallpaper collection swapped out from under DMS (flake
              # bump, GC'd path) leaves wallpaperPath pointing nowhere, so
              # matugen silently goes stale. Patch just that key with jq —
              # this is the live settings file, so no full re-seed.
              wp="$(${pkgs.jq}/bin/jq -r '.wallpaperPath // empty' "$state" 2>/dev/null)"
              if [ -n "$wp" ] && [ ! -e "$wp" ]; then
                run sh -c '${pkgs.jq}/bin/jq --arg wp "$1" ".wallpaperPath = \$wp" "$2" > "$2.tmp" && mv "$2.tmp" "$2"' \
                  -- "${cfg.initialWallpaper}" "$state"
              fi
            fi
          '';

        # Some plugins need QtWebSockets, which the shell's wrapper doesn't
        # bundle (it already brings QtMultimedia) — add it to the QML path.
        systemd.user.services.dms.Service = {
          Environment = [
            "NIXPKGS_QT6_QML_IMPORT_PATH=${pkgs.qt6.qtwebsockets}/lib/qt-6/qml"
          ];

          # The shell hits systemd's 1024-fd soft limit at startup: torn-down
          # PipeWire streams whose eventfds don't come back, crashing
          # quickshell in pw_stream_connect. Raise to the hard cap.
          LimitNOFILE = 65536;
        };

        # DMS reads the profile image from AccountsService's user icon,
        # default ~/.face.
        home.file.".face".source = ../../../assets/avatar.png;
      };
  };
}
