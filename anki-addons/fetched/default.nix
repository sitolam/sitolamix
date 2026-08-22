# Addons with a clean public upstream repo: fetched at build time instead of
# vendored, so no bytes land in git. Recipes below are lifted straight from
# nixpkgs' own pkgs/by-name/an/anki/addons/* (hashes and patches included) for
# the ones nixpkgs already packages; HyperTTS has no nixpkgs recipe so its
# fetch is written from scratch (its repo root already matches Anki's addon
# layout, no sourceRoot juggling needed).
{ pkgs }:
let
  inherit (pkgs) fetchFromGitHub;
  inherit (pkgs.stable) anki-utils;
in
{
  "1374772155" = anki-utils.buildAnkiAddon (finalAttrs: {
    pname = "image-occlusion-enhanced";
    version = "1.4.0";
    src = fetchFromGitHub {
      owner = "glutanimate";
      repo = "image-occlusion-enhanced";
      sparseCheckout = [ "src/image_occlusion_enhanced" ];
      tag = "v${finalAttrs.version}";
      hash = "sha256-YR1hicBDb08J+1Qc+SDiJDXLo5FzLqCQGeVe7brbPME=";
    };
    sourceRoot = "${finalAttrs.src.name}/src/image_occlusion_enhanced";
  });

  "1771074083" = anki-utils.buildAnkiAddon (finalAttrs: {
    pname = "review-heatmap";
    version = "1.0.1";
    src = fetchFromGitHub {
      owner = "glutanimate";
      repo = "review-heatmap";
      tag = "v${finalAttrs.version}";
      hash = "sha256-CL98DYikumoPR/QTWcMMwpd/tEpKLIDVC1Rj5NEvWJ8=";
      # Needed files are set to export-ignore in .gitattributes.
      forceFetchGit = true;
    };
    patches = [ ./patches/review-heatmap-vite-style.patch ];
    nativeBuildInputs = [
      pkgs.stable.aab
      pkgs.stable.esbuild
    ];
    buildPhase = ''
      runHook preBuild

      mkdir resources/icons/optional
      touch resources/icons/optional/{patreon.svg,thanks.svg,twitter.svg,youtube.svg}

      mkdir -p build/dist
      cp -r src resources designer --target-directory build/dist
      aab build_dist ${finalAttrs.version} --modtime -1

      esbuild \
        src/web/main.ts \
        --bundle \
        --minify \
        --target=es2015 \
        --loader:.css=text \
        --outfile=build/dist/src/review_heatmap/web/anki-review-heatmap.js

      cd build/dist/src/review_heatmap

      runHook postBuild
    '';
  });

  "688199788" = anki-utils.buildAnkiAddon (finalAttrs: {
    pname = "recolor";
    version = "3.3";
    src = fetchFromGitHub {
      owner = "AnKing-VIP";
      repo = "AnkiRecolor";
      tag = finalAttrs.version;
      sparseCheckout = [ "src/addon" ];
      hash = "sha256-Rfie1m4wfwZvmxxFngt1tky1j5dIZKX7c64A1pSbE3c=";
    };
    sourceRoot = "${finalAttrs.src.name}/src/addon";
    patches = [ ./patches/recolor-config-version.patch ];
  });

  "759844606" = anki-utils.buildAnkiAddon {
    pname = "fsrs4anki-helper";
    version = "unstable-2026-06-08";
    src = fetchFromGitHub {
      owner = "open-spaced-repetition";
      repo = "fsrs4anki-helper";
      rev = "29208f220f21ff994c199712a6aaac47636773bf";
      hash = "sha256-qoOV6cxA+oidHaKtBPVJpoc+/hitoihMRp15+IYcRnw=";
    };
    postFixup = ''
      rmdir $out/share/anki/addons/fsrs4anki-helper/python_i18n
      ln -s \
        ${pkgs.stable.python3.pkgs.python-i18n}/${pkgs.stable.python3.sitePackages} \
        $out/share/anki/addons/fsrs4anki-helper/python_i18n
    '';
  };

  "111623432" = anki-utils.buildAnkiAddon {
    pname = "hypertts";
    version = "3.5.2";
    src = fetchFromGitHub {
      owner = "Vocab-Apps";
      repo = "anki-hyper-tts";
      tag = "v3.5.2";
      hash = "sha256-2rTswnR0+OdZV40SRxvj6uNegw5uCfkKA3vJp6wrtl8=";
    };
  };
}
