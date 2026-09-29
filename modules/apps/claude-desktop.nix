{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.apps.claude-desktop;
in
{
  options.apps.claude-desktop.enable = lib.mkEnableOption "Claude Desktop (Chat, Cowork and Claude Code in one window)";

  config = lib.mkIf cfg.enable {
    # No nixpkgs package; the input repacks Anthropic's .deb. Overlay rebuilds
    # it against our nixpkgs so Electron deps share one closure. Version is
    # pinned in the input, bumped via `nix flake update`.
    nixpkgs.overlays = [ inputs.claude-desktop.overlays.default ];

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.claude-desktop ];
      };
  };
}
