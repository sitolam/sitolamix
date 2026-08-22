{
  description = "sitolamix — enable-options NixOS: niri + noctalia + stylix (catppuccin-mocha)";

  nixConfig = {
    # garnix / hyprland / lantian were dropped — see modules/system/nix.nix.
    extra-substituters = [
      "https://noctalia.cachix.org"
      "https://niri.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Escape hatch, not a second base: the current stable release, surfaced as
    # `pkgs.stable.<name>` by modules/system/nixpkgs-stable.nix. Deliberately
    # does NOT follow nixpkgs — following it would defeat the entire point.
    # Nothing uses it by default; see that module for when to reach for it.
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree.url = "github:vic/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia.url = "github:noctalia-dev/noctalia-shell";

    # niri scratchpad (Rust). packages.default = the `niri-scratchpad` binary.
    niri-scratchpad = {
      url = "github:argosnothing/niri-scratchpad-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # heyoeyo/niri_tweaks — stdlib-only python IPC scripts (no flake); we run
    # niri_tile_to_n.py at startup. flake=false => the repo is a plain src path.
    niri-tweaks = {
      url = "github:heyoeyo/niri_tweaks";
      flake = false;
    };

    # DankMaterialShell (Quickshell + Go). Tried on this branch as an
    # alternative to noctalia; drives blur via niri's ext-background-effect.
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AvengeMedia/dank-greeter — the greetd login screen that matches the DMS
    # lock screen. The flake's own nixpkgs only feeds its `packages` output; the
    # NixOS module builds dms-greeter from the importing config's pkgs.
    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helium.url = "github:FKouhai/helium2nix";

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms-plugin-registry = {
      url = "github:AvengeMedia/dms-plugin-registry";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # sitolam/dms-plugins — home-grown DMS plugins (mouthGuard, dankMenu), none
    # of them in dms-plugin-registry, so the repo is pinned as its own input.
    # Tracks the repo's default branch; local edits over in the working checkout
    # are picked up only once they are pushed and `nix flake update dms-plugins`
    # is run.
    dms-plugins = {
      url = "github:sitolam/dms-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # orangci/walls-catppuccin-mocha — a plain repo of wallpaper images, linked
    # into ~/Pictures/Wallpapers by modules/desktop/wallpapers.nix so DMS can
    # browse them. flake=false: it is images, not a flake.
    wallpapers = {
      url = "github:orangci/walls-catppuccin-mocha";
      flake = false;
    };

    # nmcbride/claude-desktop-nix — repacks Anthropic's official Linux .deb
    # (the app is not in nixpkgs and does not self-update on Linux, so the
    # version rides on this input's lock entry). Small third-party repo: read
    # the diff when updating. We consume `overlays.default`, not `packages`,
    # so it builds against our nixpkgs.
    claude-desktop = {
      url = "github:nmcbride/claude-desktop-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── Claude Code plugins ───────────────────────────────────────────────
    # modules/apps/claude-code.nix wires these into ~/.claude/plugins itself
    # rather than letting Claude clone and self-update them, so the plugin set
    # is pinned by flake.lock like everything else. All flake=false: they are
    # plugin/marketplace trees, not flakes. Bump with `nix flake update <name>`.
    #
    # Marketplaces — each holds a .claude-plugin/marketplace.json listing the
    # plugins it offers and where in the tree each one lives.
    claude-marketplace-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };

    claude-marketplace-caveman = {
      url = "github:JuliusBrussee/caveman";
      flake = false;
    };

    claude-marketplace-skills = {
      url = "github:alirezarezvani/claude-skills";
      flake = false;
    };

    claude-marketplace-flutter = {
      url = "github:cleydson/flutter-claude-code";
      flake = false;
    };

    claude-marketplace-ui-ux = {
      url = "github:nextlevelbuilder/ui-ux-pro-max-skill";
      flake = false;
    };

    # Two plugins the official marketplace only *points* at: their manifest
    # entries are `{"source":"url", ...}` rows naming another repo, so the
    # marketplace tree above does not contain them and they need their own
    # pins. Upstream pins a sha in marketplace.json; flake.lock is ours, so
    # these track the repos' default branches instead.
    claude-plugin-superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };

    claude-plugin-figma = {
      url = "github:figma/mcp-server-guide";
      flake = false;
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ (inputs.import-tree ./flake) ];
    };
}
