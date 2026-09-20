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
# ReColor's dark-mode colours follow the wallpaper. Nix writes a base
# meta.json (labels, light values and CSS var names from recolor-schema.json,
# dark slot = light value) on every activation; recolorApply then fills the
# dark slot from the colours file matugen renders from ./recolor-template.nix.
# matugen runs recolorApply as its post-hook on every wallpaper change, and
# activation runs it again so a rebuild does not reset Anki to the light
# values. Anki reads the file at startup, so a new wallpaper shows on the
# next Anki start.
{
  pkgs,
  lib,
}:
let
  inherit (pkgs.stable) anki-utils;

  recolorSchema = builtins.fromJSON (builtins.readFile ./recolor-schema.json);

  recolorColorsFile = "$HOME/.local/state/sitolamix/anki-recolor.json";

  recolorTemplate = builtins.toFile "anki-recolor.json" (
    import ./recolor-template.nix {
      inherit lib;
      keys = lib.attrNames recolorSchema;
    }
  );

  recolorBaseMeta = (pkgs.formats.json { }).generate "recolor-meta.json" {
    mod = 0;
    disabled = false;
    # This file replaces meta.json wholesale on every activation, so it has to
    # carry the flag itself or Anki puts the addon back in its update prompt.
    update_enabled = false;
    config = {
      colors = lib.mapAttrs (_key: v: [
        (builtins.elemAt v 0)
        (builtins.elemAt v 1)
        (builtins.elemAt v 1)
        (builtins.elemAt v 2)
      ]) recolorSchema;
      version = {
        major = 3;
        minor = 3;
      };
    };
  };

  recolorApply = pkgs.writeShellScript "anki-recolor-apply" ''
    colors="${recolorColorsFile}"
    meta="$HOME/.local/share/Anki2/addons21/688199788/meta.json"
    [ -e "$colors" ] && [ -e "$meta" ] || exit 0
    ${pkgs.jq}/bin/jq --slurpfile c "$colors" \
      '.config.colors |= with_entries(.value[2] = ($c[0][.key] // .value[2]))' \
      "$meta" > "$meta.tmp" && mv "$meta.tmp" "$meta"
  '';

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
    # AnkiConnect. This seed exists only to widen webCorsOriginList: the
    # stock list is ["http://localhost"], while Obsidian's renderer sends
    # Origin: app://obsidian.md, so every request from Obsidian_to_Anki is
    # refused. The failure is invisible from the outside -- that plugin's
    # onload() returns early and registers no commands at all, so it looks
    # like the plugin never installed. Still bound to loopback only.
    "2055492159"
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
  inherit
    addons
    seededIds
    recolorBaseMeta
    recolorTemplate
    recolorApply
    recolorColorsFile
    ;
  seedsDir = ./seeds;

  # Builds the home.activation script body.
  # - `secretMerges` merges live secrets into their addon's meta.json on every
  #   run, keyed by addon id; the jq filter path is relative to `.config`
  #   (meta.json's top-level config key).
  # - `themedFiles` installs a Nix-generated meta.json verbatim on every run,
  #   then runs recolorApply.
  mkActivationScript =
    {
      addonsDir, # e.g. "$HOME/.local/share/Anki2/addons21"
      secretMerges, # [{ id = "111623432"; jqPath = ".configuration.service_config.Azure.api_key"; secretPath = "/run/secrets/..."; }]
      themedFiles ? [ ], # [{ id = "688199788"; file = recolorBaseMeta; }]
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
        # Every addon here is deployed from the Nix store, so Anki must never
        # update one: its updater would overwrite repo-managed code, and the
        # next activation would silently revert that -- meanwhile Anki nags
        # with an "add-ons have updates available" dialog on every launch,
        # listing exactly these ids. `update_enabled` is set on every run
        # rather than seeded once, because Anki writes the key itself (as
        # true) for any addon folder it finds without a meta.json.
        # `disabled` is left alone, so enabling or disabling an addon from
        # Anki's own UI still works.
        if [ -e "${addonsDir}/${id}/meta.json" ]; then
          ${pkgs.jq}/bin/jq '.update_enabled = false' "${addonsDir}/${id}/meta.json" \
            > "${addonsDir}/${id}/meta.json.tmp"
          mv "${addonsDir}/${id}/meta.json.tmp" "${addonsDir}/${id}/meta.json"
        else
          ${pkgs.jq}/bin/jq -n '{mod: 0, disabled: ${
            if lib.elem id disabledIds then "true" else "false"
          }, update_enabled: false}' > "${addonsDir}/${id}/meta.json"
        fi
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
    + lib.concatStrings (map deployThemedFile themedFiles)
    + lib.optionalString (themedFiles != [ ]) ''
      ${recolorApply}
    '';
}
