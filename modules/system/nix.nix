{ inputs, ... }:
{
  # Unfree in the NixOS + home-manager closures (HM shares this via useGlobalPkgs).
  nixpkgs.config.allowUnfree = true;

  # Unfree in *ad-hoc* CLI usage too — `nix-shell -p`, `nix-build`, `nix-env`, and
  # flake commands run with `--impure` (e.g. `nix shell --impure nixpkgs#nvtop`,
  # which pulls unfree CUDA). Without this, those invocations use a nixpkgs with no
  # config and abort on the unfree/CUDA-EULA gate. The env var covers the legacy
  # tools outright; the config.nix file is the belt-and-suspenders for anything
  # that reads it.
  environment.sessionVariables.NIXPKGS_ALLOW_UNFREE = "1";
  home.extraOptions.home.file.".config/nixpkgs/config.nix".text = ''
    { allowUnfree = true; }
  '';

  nix = {
    registry.nixpkgs.flake = inputs.nixpkgs;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # flake.nix's nixConfig (extra-substituters/extra-trusted-public-keys)
      # otherwise gets ignored with a warning on every rebuild unless the
      # invocation passes --accept-flake-config. Safe here: those two lists
      # are a subset of substituters/trusted-public-keys below, already
      # trusted system-wide.
      accept-flake-config = true;

      trusted-users = [
        "root"
        "otis"
      ];

      # Four caches were dropped here (and from flake.nix):
      #   cache.garnix.io  — 502s for days at a time, and nix 2.34 does not
      #     skip a failing substituter: the download error interrupts the
      #     daemon, which then aborts during cleanup, so every rebuild dies
      #     with "Nix daemon disconnected unexpectedly". It only served
      #     zen-browser, a binary repack that is cheap to build locally.
      #   hyprland.cachix.org — nothing here uses hyprland.
      #   attic.xuyh0120.win/lantian — zero hits against this closure.
      #   noctalia.cachix.org — the noctalia shell was replaced by
      #     DankMaterialShell; nothing in this config pulls from it any more.
      # Every extra substituter is another outage that can break a rebuild, so
      # only keep the ones that actually serve this config.
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://niri.cachix.org"
      ];

      trusted-substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://niri.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      ];

      auto-optimise-store = true; # hardlink-dedupe identical store paths (saves disk)
    };

    # Garbage collection is handled by `nh clean` below (programs.nh.clean), which
    # is generation-aware. Running nix.gc *and* nh clean is redundant, so the
    # built-in timer stays off.
    gc.automatic = false;
  };

  # nh = the nice `nix os switch` wrapper (already used by the `rebuild`/`update`
  # fish aliases). Its clean timer supersedes nix.gc: it keeps a minimum number
  # of generations regardless of age, so a rebuild spree can't leave you with
  # zero rollback targets, while still reclaiming disk aggressively.
  programs.nh = {
    enable = true; # installs nh (replaces the systemPackages entry)
    flake = "/home/otis/sitolamix"; # lets `nh os switch` run with no path arg

    clean = {
      enable = true;
      dates = "daily"; # run often — this box is tight on storage
      # keep the 3 newest generations no matter what, plus anything from the last
      # 4 days. Tighten `--keep`/`--keep-since` further to reclaim more.
      extraArgs = "--keep 3 --keep-since 4d";
    };
  };
}
