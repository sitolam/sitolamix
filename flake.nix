{
  description = "sitolamix — enable-options NixOS: niri + DankMaterialShell, themed from the wallpaper";

  nixConfig = {
    extra-substituters = [
      "https://niri.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Escape hatch for packages broken on unstable (`pkgs.stable.<name>`, see modules/system/nixpkgs-stable.nix); deliberately not following nixpkgs.
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    # Structures this flake's outputs (auto-discovers hosts, merges modules).
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Auto-imports every module under modules/ — no manual imports list.
    import-tree.url = "github:vic/import-tree";

    # Home-manager itself; not in nixpkgs as a usable module set.
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri's own NixOS/home-manager module; upstream niri ships none.
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Our own keyboard-shortcut trainer, drilled against niri's binds; nothing comparable in nixpkgs.
    keydrill = {
      url = "github:sitolam/keydrill";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Scratchpad terminal for niri, not in nixpkgs.
    niri-scratchpad = {
      url = "github:argosnothing/niri-scratchpad-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Python IPC scripts for niri (we run niri_tile_to_n.py at startup); no flake, not in nixpkgs.
    niri-tweaks = {
      url = "github:heyoeyo/niri_tweaks";
      flake = false;
    };

    # DankMaterialShell: the bar, panels, control center, lock screen and plugin host. Not in nixpkgs.
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The greetd login screen matching the DMS lock screen. Not in nixpkgs.
    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen browser packaging; not in nixpkgs.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Repacks imputnet's official Helium .deb with patchelf and ships a NixOS module. Not in nixpkgs.
    helium = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Runs a single Windows app over RDP in RemoteApp mode. Not in nixpkgs, no module either — modules/services/winapps does the wiring.
    winapps = {
      url = "github:winapps-org/winapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Spotify theming/module; not in nixpkgs.
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Daily mirror of the VS Code Marketplace/Open VSX, used only for the few extensions nixpkgs lacks.
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # DMS plugin registry — source for modules/desktop/dms/plugins.nix builds.
    dms-plugin-registry = {
      url = "github:AvengeMedia/dms-plugin-registry";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Our own DMS plugins; kept only for mouthGuard, which needs wrapping with this flake's own `mouthguard-detector` package (see modules/desktop/dms/plugins.nix).
    dms-plugins = {
      url = "github:sitolam/dms-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Fork of dms-take-a-break adding countOnlyActiveUse; modules/desktop/dms/plugins.nix overrides `src` for this one plugin.
    dms-take-a-break = {
      url = "github:sitolam/dms-take-a-break";
      flake = false;
    };

    # DMS's fork of NvChad's base46 colour engine, carrying the `_DMS_SUPPORT` marker nixpkgs' unforked copy lacks.
    base46-dms = {
      url = "github:AvengeMedia/base46";
      flake = false;
    };

    # Our wallpaper collection (modules/desktop/wallpapers.nix); DMS derives every desktop colour from these. Images, not a flake.
    wallpapers = {
      url = "github:sitolam/mywalls";
      flake = false;
    };

    # Repacks Anthropic's official Linux .deb; not in nixpkgs, doesn't self-update.
    claude-desktop = {
      url = "github:nmcbride/claude-desktop-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Our repack of StayFree's proprietary AppImage; not in nixpkgs (NixOS/nixpkgs#338978).
    stayfree = {
      url = "github:sitolam/stayfree-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Code plugins/marketplaces, wired into ~/.claude/plugins by modules/apps/claude-code.nix and pinned via flake.lock instead of letting Claude self-update them. All flake=false, not in nixpkgs.
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

    # Plugins the official marketplace only points at by URL, so they need their own pin here.
    claude-plugin-superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };

    claude-plugin-figma = {
      url = "github:figma/mcp-server-guide";
      flake = false;
    };

    # Single-plugin repo, pinned directly since no tracked marketplace lists it.
    claude-plugin-mattpocock = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    # Cursor's plugin monorepo, for `pstack`; claude-code.nix bolts on a Claude manifest since it only ships .cursor-plugin/plugin.json.
    claude-plugin-pstack = {
      url = "github:cursor/plugins";
      flake = false;
    };

    # Windows Hello-style face auth (modules/hardware/gaze.nix). Not in nixpkgs. Follows our nixpkgs: gaze needs onnxruntime >= 1.21's OpenVINO provider, and a separate pin would link a second ONNX Runtime.
    gaze = {
      url = "github:GunduLabs/gaze";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets encrypted at rest, decrypted into place at activation.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Per-hardware NixOS modules (kernel params, quirks) for supported devices.
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ (inputs.import-tree ./flake) ];
    };
}
