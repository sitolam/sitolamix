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
  # bindings.nix (niri-scratchpad-rs).

  options.desktop.niri.enable = lib.mkEnableOption "niri scrollable Wayland compositor";

  config = lib.mkIf cfg.enable {
    # nixpkgs removed `libdisplay-info_0_2`, but niri-flake still builds niri
    # against it and asserts exactly version 0.2.0, so evaluating
    # programs.niri.package hits the removal throw. Reinstate it ourselves
    # (same upstream expression, src pinned back to 0.2.0) until niri-flake
    # stops asking for it.
    #
    # Applied via `overlays.niri`, not `inputs.niri.packages`: the latter's
    # `packages.<system>` is built from a pkgs instance we can't add overlays
    # to, while `overlays.niri` builds the same packages from *our* pkgs.
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
    #  - niri-scratchpad: the Mod+M scratchpad binary (see bindings.nix)
    #  - playerctl: XF86AudioPlay/Next/Prev binds (see bindings.nix)
    environment.systemPackages = with pkgs; [
      grim
      slurp
      wl-clipboard
      tesseract
      hyprpicker
      python3
      playerctl
      inputs.niri-scratchpad.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # login manager lives in modules/desktop/greetd.nix (greetd + DMS Greeter,
    # which launches its own niri using programs.niri.package above)

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome
      ];
    };

    services.dbus.enable = true;

    # niri-flake's module unconditionally starts a second polkit agent
    # (niri-flake-polkit) with no option to turn it off. Running it alongside
    # polkit_gnome below makes both race to register, and the loser
    # crash-loops. Masked so polkit_gnome (GTK) is the only agent.
    systemd.user.services.niri-flake-polkit.enable = false;

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
