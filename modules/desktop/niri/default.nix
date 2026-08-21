{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.desktop.niri;
in
{
  imports = [ inputs.niri.nixosModules.niri ];

  # niri tweaks live under startup.nix (niri_tile_to_n.py auto-tiler) and
  # bindings.nix (niri-scratchpad-rs). TODO: consider MintyDoggo/miri later
  # (https://github.com/MintyDoggo/miri) as an alternative tweak layer.

  options.desktop.niri.enable = lib.mkEnableOption "niri scrollable Wayland compositor";

  config = lib.mkIf cfg.enable {
    # nixpkgs dropped `libdisplay-info_0_2` ("has been removed as it is was
    # unused in Nixpkgs"), but niri-flake still builds niri against it and
    # asserts the version is exactly 0.2.0, so evaluating programs.niri.package
    # hits the removal throw. niri-flake has not moved since 2026-08-04, so we
    # put the package back ourselves: same upstream expression, our nixpkgs,
    # only the src pinned back to 0.2.0 (the C ABI niri's libdisplay-info-sys
    # 0.3 crate probes for; it accepts >= 0.1.0 < 0.4.0, so 0.3.0 would work
    # too — but it cannot satisfy niri-flake's assert).
    # Drop this once niri-flake stops asking for _0_2.
    #
    # The fix only reaches niri through niri-flake's own overlay: its
    # `packages.<system>` output is built from a pkgs instance we cannot add
    # overlays to, while `overlays.niri` builds the same packages from *our*
    # pkgs — so niri-unstable comes from `pkgs`, not from `inputs.niri.packages`.
    nixpkgs.overlays = [
      (_final: prev: {
        libdisplay-info_0_2 = prev.libdisplay-info.overrideAttrs (
          finalAttrs: _: {
            version = "0.2.0";
            src = prev.fetchFromGitLab {
              domain = "gitlab.freedesktop.org";
              owner = "emersion";
              repo = "libdisplay-info";
              tag = finalAttrs.version;
              hash = "sha256-6xmWBrPHghjok43eIDGeshpUEQTuwWLXNHg7CnBUt3Q=";
            };
          }
        );
      })
      inputs.niri.overlays.niri
    ];

    programs.niri = {
      enable = true;
      package = pkgs.niri-unstable;
    };

    # tools for the region-screenshot / OCR / color-pick keybinds, plus:
    #  - python3: runs the niri_tile_to_n.py auto-tiler (see startup.nix)
    #  - niri-scratchpad: the Mod+M/Mod+S scratchpad binary (see bindings.nix)
    environment.systemPackages = with pkgs; [
      grim
      slurp
      wl-clipboard
      tesseract
      hyprpicker
      python3
      inputs.niri-scratchpad.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # login manager lives in modules/desktop/greetd.nix (greetd + DMS Greeter,
    # which launches its own niri using programs.niri.package above)

    # xdg-portals for wayland
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome
      ];
    };

    # dbus + polkit gui agent
    services.dbus.enable = true;
    systemd.user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };
}
