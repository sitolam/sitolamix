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
    users.users.otis.extraGroups = [ "i2c" ];

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
    ];

    home.extraOptions =
      { config, pkgs, ... }:
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
            postFixup =
              (old.postFixup or "")
              + ''
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

          # session.json — night mode (auto, IP-located). stylix sets the
          # wallpaper keys here too; these merge with those.
          session = {
            weatherLocation = "Eeklo, 9900";
            weatherCoordinates = "51.2,3.6";

            nightModeEnabled = true;
            nightModeAutoEnabled = true;
            nightModeAutoMode = "location";
            nightModeUseIPLocation = true;
            nightModeTemperature = 5000;
            nightModeHighTemperature = 6500;
          };
        };

        # DMS only reads its settings at startup, and the systemd user service's
        # unit doesn't change when only settings.json/the theme file change — so
        # nothing restarts it on rebuild. Trigger a restart (via sd-switch) when
        # the generated settings.json changes, so theme/blur edits take effect
        # after `nixos-rebuild switch` without a manual restart or relogin.
        systemd.user.services.dms.Unit.X-Restart-Triggers = [
          config.xdg.configFile."DankMaterialShell/settings.json".source
        ];

        # the Home Assistant plugin does `import QtWebSockets`, which quickshell
        # doesn't bundle. Add the module to the shell's QML path (the quickshell
        # wrapper prefixes NIXPKGS_QT6_QML_IMPORT_PATH, so this value is kept).
        systemd.user.services.dms.Service.Environment = [
          "NIXPKGS_QT6_QML_IMPORT_PATH=${pkgs.qt6.qtwebsockets}/lib/qt-6/qml"
        ];

        # DMS reads the profile image from the AccountsService user icon, which
        # defaults to ~/.face (confirmed via busctl). So just put the avatar
        # there — no AccountsService plumbing needed.
        home.file.".face".source = ../../../assets/avatar.png;
      };
  };
}
