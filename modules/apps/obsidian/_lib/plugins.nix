# Community-plugin set for the Obsidian vault, fetched from each plugin's
# GitHub release. Obsidian has no package manager Nix can drive, and nixpkgs
# carries no plugin set, so the releases are pinned by hash here and copied
# into `<vault>/.obsidian/plugins/<id>/` on activation.
#
# import-tree skips any path containing `/_`, so this is *not* loaded as a
# NixOS module even though it lives under modules/.
#
# Bumping a plugin: raise `version`, then
#   nix-prefetch-url https://github.com/<repo>/releases/download/<version>/main.js
# for each of the three files (and `nix hash convert --to sri`).
{ pkgs, lib }:
let
  # Release assets are always main.js + manifest.json, usually plus
  # styles.css, so `hashes` names whichever files the plugin actually ships.
  mkPlugin =
    {
      id,
      repo,
      version,
      hashes,
    }:
    {
      inherit id version;
      files = lib.mapAttrs (
        file: hash:
        pkgs.fetchurl {
          url = "https://github.com/${repo}/releases/download/${version}/${file}";
          inherit hash;
        }
      ) hashes;
    };
in
map mkPlugin [
  {
    # The reason this vault exists: snippets + tabstops that make typing
    # LaTeX as fast as handwriting. Castel's UltiSnips setup, in Obsidian.
    id = "obsidian-latex-suite";
    repo = "artisticat1/obsidian-latex-suite";
    version = "1.12.8";
    hashes = {
      "main.js" = "sha256-xUGgAMXhbCkRNndOg436E2mxRMOIdBf0Zg4NUEy9D90=";
      "manifest.json" = "sha256-o0GEtdTJm/00sBjsMv3xcAOXl7sutxjbuHc9c/wHcow=";
      "styles.css" = "sha256-tFde2nGNUFYEpL7GnWytygbOS9sfC0UINHbxAC3JTmI=";
    };
  }
  {
    # Detexify in a side panel: draw the symbol you cannot name, get the
    # command. The other half of Latex Suite — snippets only help once you
    # know what the thing is called.
    id = "latex-symbol-picker";
    repo = "Ryxwaer/obsidian-latex-symbol-picker";
    version = "1.3.0";
    hashes = {
      "main.js" = "sha256-MsMgRi9mqSYAUleCDmttqg9wP2ME/alqFTx0ckDxd3A=";
      "manifest.json" = "sha256-kkcnkRtNrAgQNkUSF67JA3R3EFxgAbAwebSrLtEoYTY=";
      "styles.css" = "sha256-sH8HdHV3IhsmKT4rgZefAz4HMjYQlgu6AN4Y+AD9eP4=";
    };
  }
  {
    # Figures during a lecture, without leaving the note. Draws to
    # .excalidraw.md files that embed straight into a note.
    id = "obsidian-excalidraw-plugin";
    repo = "zsviczian/obsidian-excalidraw-plugin";
    version = "2.27.2";
    hashes = {
      "main.js" = "sha256-6fV3AfbkjgohNu2GtFwF7lEt6Vos+3DbFShBnfURuIU=";
      "manifest.json" = "sha256-tIMULn6rsu5BEi2X0HkSz0hc1x6GgIAVwIv9TVM2iB0=";
      "styles.css" = "sha256-SpsyniSr3DEMzYoPuRx4Y2Gc7qKg0maYGobWxevRq+o=";
    };
  }
  {
    # Auto-commits the vault. This is the whole backup story — see the
    # `vault` option's comment in ../default.nix.
    id = "obsidian-git";
    repo = "Vinzent03/obsidian-git";
    version = "2.39.0";
    hashes = {
      "main.js" = "sha256-1adANs8XwaApV8HzP1nkfPOvg1JWQcQ3TKH6CdlfPrQ=";
      "manifest.json" = "sha256-JwQQ7dbmT1HZdDQ8binsg5lQL24FeuXWJk0lmxBPYlw=";
      "styles.css" = "sha256-9auT9NW03RvR5XeGTFx5CH9639RIrDRuBInlhHzmki0=";
    };
  }
  {
    # Note templates with date/prompt substitution (99 Meta/Templates).
    id = "templater-obsidian";
    repo = "SilentVoid13/Templater";
    version = "2.25.0";
    hashes = {
      "main.js" = "sha256-ail5DorTuz3lvMc4FYjyAJOy2+zB/yfYpdftP867304=";
      "manifest.json" = "sha256-dZhRiPrItRjuu3kTcKJNrhokdszjkS3kcJd4294BceQ=";
      "styles.css" = "sha256-65QGO+YCZ585fj41/Lf2pLAn2oLhfCE7tEomfGtF2N4=";
    };
  }
  {
    # Numbered theorem/definition environments and \ref-style links between
    # them across the vault. Manifest id is still the old "math-booster";
    # the repo was renamed to obsidian-latex-theorem-equation-referencer.
    id = "math-booster";
    repo = "RyotaUshio/obsidian-latex-theorem-equation-referencer";
    version = "2.2.0";
    hashes = {
      "main.js" = "sha256-tzq5pVkFvVrRzokM5FLakhnu3c2X9yUwdqbG90pnRMA=";
      "manifest.json" = "sha256-mfK00Tb+ouJpgQUzLg91YT5yy7z4r53rgRJKKY5fHfA=";
      "styles.css" = "sha256-edMt+9X/idtjAvf2wRsD2bMwhu7NjtNQRl7Y8FYeyOo=";
    };
  }
  {
    # Hard dependency of math-booster: without it that plugin refuses to load
    # and shows a "requires the following plugin" dialog on startup. Renders
    # the theorem's statement inside the link text.
    id = "mathlinks";
    repo = "zhaoshenzhai/obsidian-mathlinks";
    version = "0.5.3";
    hashes = {
      "main.js" = "sha256-1FcHLAh6abih6q9d2Trj9QhZ2vr861ie0aNdFCDtxko=";
      "manifest.json" = "sha256-4Y3i05cX3eYT0+qkMQprYsOZYZwhORm8HQszjGGnTZI=";
    };
  }
  {
    # Vanilla Obsidian does not render $...$ inside a callout, which is where
    # every theorem statement ends up once math-booster is in play.
    id = "math-in-callout";
    repo = "RyotaUshio/obsidian-math-in-callout";
    version = "0.3.8";
    hashes = {
      "main.js" = "sha256-/+LlAir6iDo1eW3sVHbXwF1MkTeaMXa9COqPIze7Fag=";
      "manifest.json" = "sha256-ivvR18PQ9+bCti5z+HT/1RshK4cixkh1gqzVTCX+fX4=";
      "styles.css" = "sha256-b/EKIG3s+w4Dv8wBNWv6imeryDcGPuY0VH46dswnEYg=";
    };
  }
  {
    # Pushes flashcards written in the notes into the Anki collection that
    # ../anki already manages. Needs AnkiConnect (addon 2055492159), which
    # ../anki/_lib ships.
    id = "obsidian-to-anki-plugin";
    repo = "ObsidianToAnki/Obsidian_to_Anki";
    version = "3.6.0";
    hashes = {
      "main.js" = "sha256-3MpVnIABoEH/EaXe9Mb5CWlpUUJJ0ZONt47Gp+5Vv+8=";
      "manifest.json" = "sha256-SzzKQjJmqKyIKTVAXvCDRS/tVJmzOBGohke1NkWX+z4=";
      "styles.css" = "sha256-iv3uGArAQeYdLA0FPhyVOqR22VxjKiu+Yz6lfD7/LBM=";
    };
  }
  {
    # Drives the per-course dashboards: lists lectures and unfinished
    # exercises by querying note frontmatter.
    id = "dataview";
    repo = "blacksmithgu/obsidian-dataview";
    version = "0.5.70";
    hashes = {
      "main.js" = "sha256-a7HPcBCvrYMOc1dfyg4r+9MnnFYuPZ0k8tL0UWHrfQA=";
      "manifest.json" = "sha256-kjXbRxEtqBuFWRx57LmuJXTl5yIHBW6XZHL5BhYoYYU=";
      "styles.css" = "sha256-MwbdkDLgD5ibpyM6N/0lW8TT9DQM7mYXYulS8/aqHek=";
    };
  }
]
