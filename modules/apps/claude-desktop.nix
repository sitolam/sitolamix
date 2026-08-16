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
    # Anthropic ships the Linux app only as a .deb from their own apt repo, and
    # nixpkgs has no package for it. The input repacks *that* .deb (unlike the
    # older flakes that wrap the Windows/macOS build). The overlay builds it
    # against our nixpkgs instead of the input's own, so the Electron runtime
    # deps come from one closure. Version is pinned in the input's package.nix —
    # the app does not self-update on Linux, `nix flake update` is the bump.
    nixpkgs.overlays = [ inputs.claude-desktop.overlays.default ];

    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.claude-desktop ];
      };
  };
}
