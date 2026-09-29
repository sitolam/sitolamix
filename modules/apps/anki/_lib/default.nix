# Anki addons deployed into the real, mutable ~/.local/share/Anki2/addons21,
# not pkgs.anki.withAddons (blocks the GUI's save-config flow). Code
# redeploys every activation; meta.json is left alone once it exists.
#
# HyperTTS/Anki Leaderboard secrets are stripped from vendored config and
# re-merged from sops every activation, see `secretMerges` below.
#
# ReColor's dark colours follow the wallpaper: recolorApply fills the dark
# slot from matugen's rendered colours.
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
    update_enabled = false; # or Anki puts the addon back in its update prompt
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

  # copied to meta.json only on first install, never overwriting an existing one
  seededIds = [
    "1100811177"
    "111623432" # HyperTTS
    "1247171202"
    "1708250053"
    # AnkiConnect: widens webCorsOriginList so Obsidian's app://obsidian.md
    # origin isn't silently refused; still loopback only.
    "2055492159"
    "175794613" # Anki Leaderboard
    "24411424"
    "805891399"
    "efficiency_tracker"
  ];

  disabledIds = [
    "175794613" # Anki Leaderboard
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

  # secretMerges: jq filter path relative to `.config`. themedFiles installs a
  # Nix-generated meta.json verbatim, then runs recolorApply.
  mkActivationScript =
    {
      addonsDir,
      secretMerges, # [{ id, jqPath, secretPath }]
      themedFiles ? [ ], # [{ id, file }]
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
        # Anki must never update a store-deployed addon: it writes
        # update_enabled=true itself for any addon folder without meta.json,
        # so reset it every run; `disabled` is left for Anki's own UI to toggle.
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
