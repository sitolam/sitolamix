# Anki addons, managed declaratively but deployed into the *real*, mutable
# ~/.local/share/Anki2/addons21 (not via pkgs.anki.withAddons's ANKI_ADDONS
# env var, which replaces addons21 wholesale, forces every addon read-only in
# the nix store, and blocks the GUI "save config" flow). Each addon's code is
# redeployed from here on every home-manager activation; its meta.json (mod
# time, enabled flag, and whatever config the user has tweaked via the GUI) is
# left alone once it exists, so GUI edits survive rebuilds.
#
# Two addons hold live secrets (HyperTTS's Azure key, Anki Leaderboard's auth
# token) which are stripped from their vendored/seeded config and re-merged in
# from sops on every activation instead -- see `secretMerges` below and how
# ../default.nix wires it to config.sops.secrets.*.path.
#
# This tree sits under `_lib` on purpose: import-tree's default filter skips
# any path containing `/_`, so none of these data files are mistaken for NixOS
# modules. ../default.nix imports it explicitly.
#
# ReColor's colors are theme-driven rather than a static seed: its dark-mode
# swatches come from the active theme's `recolor` table (themes/<name>.nix),
# resolved against `recolorSchema` (ReColor's own shipped labels/light
# values/css var names, captured once in recolor-schema.json since they never
# change). The result is written to its meta.json on *every* activation (not
# just first-install), so switching the active theme re-colors Anki too.
{
  pkgs,
  lib,
  theme,
}:
let
  inherit (pkgs.stable) anki-utils;

  recolorSchema = builtins.fromJSON (builtins.readFile ./recolor-schema.json);

  resolveSwatch = v: if lib.hasPrefix "#" v then v else theme.palette.${v};

  recolorColors = lib.mapAttrs (
    key: schemaVal:
    let
      label = builtins.elemAt schemaVal 0;
      light = builtins.elemAt schemaVal 1;
      cssvar = builtins.elemAt schemaVal 2;
      dark = resolveSwatch (
        theme.recolor.${key} or (throw "themes/${theme.themeName}.nix: recolor.${key} is not set")
      );
    in
    [
      label
      light
      dark
      cssvar
    ]
  ) recolorSchema;

  recolorMetaFile = (pkgs.formats.json { }).generate "recolor-meta.json" {
    mod = 0;
    disabled = false;
    config = {
      colors = recolorColors;
      version = {
        major = 3;
        minor = 3;
      };
    };
  };

  fetched = import ./fetched { inherit pkgs; };

  # id -> nothing but source (buildAnkiAddon with a local src is enough;
  # pname only labels the store path, our activation script deploys by id).
  vendoredIds = [
    "1100811177" # syntax highlighting fork (css + night mode)
    "1247171202" # Study Time Stats
    "1362209126" # Quizlet to Anki 21 Importer with audio support (JDMaybeMD fork)
    "1442112168" # PDF Exporter
    "1566095810" # Multiple Choice
    "1708250053" # Progress bar (Shigeyuki fork)
    "175794613" # Anki Leaderboard (Shigeyuki fork)
    "1779572689" # Deck duplication
    "1906641654" # See Previous Ratings
    "2084557901" # LPCG Lyrics/Poetry Cloze Generator
    "24411424" # Customize Keyboard Shortcuts
    "2494384865" # Button Colours Good Again
    "699175524" # Deck name in title 21
    "800604861" # Copy notes (Shigeyuki fork)
    "805891399" # extended field editor (tables, search & replace, TinyMCE6)
    "advanced_deck_maker" # own addon: multi-deck creation via || splits / {brace} expansion
    "efficiency_tracker" # own addon: study efficiency tracker
  ];

  vendored = lib.listToAttrs (
    map (id: {
      name = id;
      value = anki-utils.buildAnkiAddon {
        pname = "anki21-${id}";
        version = "0";
        src = ./vendored/${id};
      };
    }) vendoredIds
  );

  addons = fetched // vendored;

  # ids with a captured _meta.seed.json under ./seeds -- copied to meta.json
  # only on first install, never overwriting a meta.json that already exists.
  seededIds = [
    "1100811177"
    "111623432" # HyperTTS
    "1247171202"
    "1708250053"
    "175794613" # Anki Leaderboard
    "24411424"
    "805891399"
    "efficiency_tracker"
  ];

  # ids that were actually disabled in Anki's own meta.json on the old
  # machine (checked all 22 -- this is the only one). Everything else,
  # including addons with no seed at all, was enabled, which matches what
  # Anki does by default for a freshly-discovered addon folder -- so only
  # this list needs special-casing.
  disabledIds = [
    "175794613" # Anki Leaderboard -- was off, keep it off
  ];
in
{
  inherit addons seededIds recolorMetaFile;
  seedsDir = ./seeds;

  # Builds the home.activation script body.
  # - `secretMerges` merges live secrets into their addon's meta.json on every
  #   run, keyed by addon id; the jq filter path is relative to `.config`
  #   (meta.json's top-level config key).
  # - `themedFiles` installs a fully Nix-generated meta.json verbatim on every
  #   run (no seed-once check) -- for addons like ReColor whose config should
  #   always match the current theme, not just the first install.
  mkActivationScript =
    {
      addonsDir, # e.g. "$HOME/.local/share/Anki2/addons21"
      secretMerges, # [{ id = "111623432"; jqPath = ".configuration.service_config.Azure.api_key"; secretPath = "/run/secrets/..."; }]
      themedFiles ? [ ], # [{ id = "688199788"; file = recolorMetaFile; }]
    }:
    let
      deployOne = id: drv: ''
        addonSrc=(${drv}/share/anki/addons/*/)
        install -d "${addonsDir}/${id}"
        chmod -R u+w "${addonsDir}/${id}"
        ${pkgs.rsync}/bin/rsync -a --chmod=Du=rwx,Fu=rw --delete --exclude='meta.json' --exclude='user_files/' "''${addonSrc[0]}" "${addonsDir}/${id}/"
        ${
          if lib.elem id seededIds then
            ''
              if [ ! -e "${addonsDir}/${id}/meta.json" ]; then
                install -m 0600 "${./seeds}/${id}.json" "${addonsDir}/${id}/_seed_config.json"
                ${pkgs.jq}/bin/jq -n --slurpfile c "${addonsDir}/${id}/_seed_config.json" \
                  '{mod: 0, disabled: ${
                    if lib.elem id disabledIds then "true" else "false"
                  }, config: $c[0]}' > "${addonsDir}/${id}/meta.json"
                rm -f "${addonsDir}/${id}/_seed_config.json"
              fi
            ''
          else
            ""
        }
      '';

      mergeSecret = m: ''
        if [ -e "${addonsDir}/${m.id}/meta.json" ] && [ -e "${m.secretPath}" ]; then
          ${pkgs.jq}/bin/jq --arg v "$(cat "${m.secretPath}")" \
            '.config${m.jqPath} = $v' "${addonsDir}/${m.id}/meta.json" > "${addonsDir}/${m.id}/meta.json.tmp"
          mv "${addonsDir}/${m.id}/meta.json.tmp" "${addonsDir}/${m.id}/meta.json"
        fi
      '';

      deployThemedFile = t: ''
        install -m 0644 "${t.file}" "${addonsDir}/${t.id}/meta.json"
      '';
    in
    ''
      install -d "${addonsDir}"
    ''
    + lib.concatStrings (lib.mapAttrsToList deployOne addons)
    + lib.concatStrings (map mergeSecret secretMerges)
    + lib.concatStrings (map deployThemedFile themedFiles);
}
