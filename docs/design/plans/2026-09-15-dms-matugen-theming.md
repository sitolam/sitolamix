# Wallpaper-driven theming (DMS matugen) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove stylix and the catppuccin palette; every themed surface takes its colours from the current wallpaper through DankMaterialShell's matugen, with dharmx/walls as the wallpaper collection.

**Architecture:** DMS runs matugen whenever the wallpaper changes. Its built-in templates cover GTK, Qt, niri, ghostty, zed, VS Code, neovim, zen and vesktop. A new `theming.matugen` module collects per-app *user* templates (Obsidian, Anki, Spotify) into `~/.config/matugen/config.toml`, which DMS appends to its own run. Non-colour settings stylix used to own (cursor, icons, fonts, Qt platform theme) move into that module and into the app modules.

**Tech Stack:** NixOS flake (flake-parts, import-tree), home-manager, DankMaterialShell 1.6.1, matugen 4.2.0, spicetify-nix, niri-flake.

**Spec:** `docs/design/specs/2026-09-15-dms-matugen-theming-design.md`

## Global Constraints

- Branch: `dms-mutagen`. Never push, never touch `main`.
- A feature is one file (or one directory with sidecars). No `imports` lists under `modules/`.
- No hex colour literal in any `.nix` file when done. Colours live in matugen templates only (template files contain `{{colors.*}}` / `{{dank16.*}}` tokens, not hex).
- Always dark. Write only dark/`default` tokens.
- `matugenScheme = "scheme-tonal-spot"`, declared in Nix.
- GRUB keeps `pkgs.catppuccin-grub` (`modules/system/boot/grub.nix` untouched).
- Every workaround comment says why it exists and when it can be removed.
- Every new flake input has a comment saying what it is and why it is not in nixpkgs.
- Never edit `flake.lock` by hand; use `nix flake lock` / `nix flake update <input>`.
- Do not run `nixos-rebuild switch` / `nh os switch` / `just rebuild` without asking the user first.
- Each task ends green on: `just fmt`, `just check`, and
  `nix shell nixpkgs#statix nixpkgs#deadnix --command sh -c 'statix check .; deadnix modules/ hosts/ themes/ flake/ flake.nix'`
  (drop `themes/` from the deadnix call once Task 7 deletes it).
- Commit messages end with:
  ```
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01QaJ4aPtcZ2XQDY8iDdAWeH
  ```

## Reference facts (verified 2026-09-15)

- matugen token syntax: `{{colors.<role>.default.hex}}`, `.hex_stripped`, `.red`/`.green`/`.blue` (0–255), `.hue`, `.saturation`, `.lightness`. DMS injects `{{dank16.color0..color15.default.hex}}` with the same sub-fields.
- User templates: DMS reads the `[templates]` section of `~/.config/matugen/config.toml` when setting `runUserMatugenTemplates = true` (`core/internal/matugen/matugen.go`, `buildMergedConfig`). Template keys: `input_path`, `output_path`, optional `post_hook`.
- Built-in outputs: `~/.config/niri/dms/colors.kdl`, `~/.config/ghostty/themes/dankcolors`, `~/.config/zed/themes/dank-zed-theme.json` (theme name `DankShell Dark`), VS Code extension `dms-theme` (theme label `Dynamic Base16 DankShell (Dark)`), `~/.config/nvim/colors/dms.lua` (needs the `AvengeMedia/base46` plugin), `~/.config/DankMaterialShell/zen.css`, `~/.config/vesktop/themes/dank-discord.css`, `~/.config/gtk-3.0/dank-colors.css`, `~/.config/gtk-4.0/dank-colors.css`, `~/.config/qt6ct/colors/matugen.conf`.
- DMS's `scripts/gtk.sh` copies `adw-gtk3` from `XDG_DATA_DIRS` into `~/.local/share/themes` and injects `@import url("dank-colors.css");` into `gtk.css`. It **refuses** if `gtk.css` is a home-manager symlink. So home-manager must not own `gtk-3.0/gtk.css` or `gtk-4.0/gtk.css`.
- DMS's `scripts/qt.sh` edits `qt5ct.conf`/`qt6ct.conf` itself. home-manager must not own those files.
- `isLightMode` lives in `session.json` (seeded, runtime), default `false`.
- DMS niri include option `programs.dank-material-shell.niri.includes.filesToInclude` accepts `"colors"`.
- spicetify-nix: `programs.spicetify.spotifyPackage` is the input; the builder keeps the input's `postFixup` and runs it after `spicetify apply`. The spiced build loads `Apps/xpui/colors.css` via `<link ... href='colors.css'>`.
- Values stylix currently sets, to preserve:
  - DMS: `fontFamily = "DejaVu Sans"`, `monoFontFamily = "MesloLGS Nerd Font Mono"`.
  - ghostty: `background-opacity = 0.8`.
  - zed: `buffer_font_family = "MesloLGS Nerd Font Mono"`, `buffer_font_size = 20`, `ui_font_family = "DejaVu Sans"`, `ui_font_size = 16`.
  - VS Code: `editor.fontFamily`/`terminal`/`debug.console`/`scm.inputFontFamily` = `"MesloLGS Nerd Font Mono"`, `editor.fontSize = 20`, `terminal.integrated.fontSize = 20`, `markdown.preview.fontFamily`/`chat.fontFamily` = `"DejaVu Sans"`.
  - cursor `Bibata-Modern-Classic` size 7 (omnibook 16); icons `WhiteSur`.
- Programs stylix auto-themed that need a replacement: bat, btop, fish, fzf, lazygit, starship, tmux, yazi, neovim, ghostty, vscode, zed, gtk, qt, dank-material-shell.

## File map

| File | Change |
|---|---|
| `modules/theming/matugen.nix` | **create** — `theming.matugen` options, config.toml, cursor/icons/GTK/Qt |
| `modules/theming/stylix.nix` | delete |
| `themes/default.nix`, `themes/catppuccin-mocha.nix` | delete |
| `modules/apps/obsidian/default.nix` | template instead of activation-written CSS |
| `modules/apps/obsidian/_lib/matugen-css.nix` | **create** — builds the template text (fonts/callouts in Nix, colours as tokens) |
| `modules/apps/anki/default.nix`, `modules/apps/anki/_lib/default.nix` | ReColor colours from template + post-hook |
| `modules/apps/anki/recolor.json` | **create** — template |
| `modules/apps/spotify.nix` → `modules/apps/spotify/default.nix` | colors.css symlink + template |
| `modules/apps/spotify/colors.css` | **create** — template |
| `modules/desktop/dms/theme.nix`, `default.nix`, `bar.nix`, `niri.nix` | dynamic theme on |
| `modules/desktop/niri/appearance.nix` | drop stylix colours |
| `modules/desktop/wallpapers.nix` | dharmx/walls, `nature/` default |
| `modules/apps/{ghostty,zed,vscode,starship,cli,neovim}.nix` | explicit theme/font settings |
| `modules/suites/{desktop,browser,social}.nix` | enable `theming.matugen`, zen + vesktop wiring |
| `modules/apps/helium/default.nix` | GTK theme mode pref |
| `hosts/omnibook/default.nix` | cursor size option |
| `flake.nix` | drop stylix, swap wallpapers, add base46 |
| `CLAUDE.md`, `README.md`, `modules/system/fonts.nix`, `modules/system/nixpkgs-stable.nix`, `modules/desktop/niri/default.nix` | docs/comments |

---

### Task 1: Spotify colours through an out-of-store symlink (feasibility gate)

The whole Spotify approach depends on Spotify's embedded Chromium following a symlink from the store to `$HOME`. Prove it before building anything on it.

**Files:**
- Modify (temporarily, reverted in Step 6): `modules/apps/spotify.nix`

**Interfaces:**
- Produces: a yes/no answer recorded in the Task 5 commit message. No code kept.

- [ ] **Step 1: Add a throwaway postFixup to the spotify package**

In `modules/apps/spotify.nix`, inside `programs.spicetify = { ... }`, add:

```nix
spotifyPackage = pkgs.spotify.overrideAttrs (old: {
  postFixup = (old.postFixup or "") + ''
    ln -sf /home/otis/.config/spicetify-dms/colors.css $out/share/spotify/Apps/xpui/colors.css
  '';
});
```

- [ ] **Step 2: Build it without switching**

Run:
```sh
nix build .#nixosConfigurations.$(hostname).config.home-manager.users.otis.programs.spicetify.spicedSpotify -o /tmp/claude-1000/-home-otis-sitolamix/0339397a-0f23-4a6d-868c-c88af6bc6e43/scratchpad/spiced
readlink /tmp/claude-1000/-home-otis-sitolamix/0339397a-0f23-4a6d-868c-c88af6bc6e43/scratchpad/spiced/share/spotify/Apps/xpui/colors.css
```
Expected: `/home/otis/.config/spicetify-dms/colors.css`.

If the build fails because `postFixup` is not run (the link is missing), stop and report to the user: the fallback (mutable spicetify-cli) needs their approval.

- [ ] **Step 3: Write an obviously wrong colour file**

```sh
mkdir -p ~/.config/spicetify-dms
cp /nix/store/*-spicetify-Sleek/share/spotify/Apps/xpui/colors.css ~/.config/spicetify-dms/colors.css 2>/dev/null || true
sed -i 's/--spice-main: #[0-9a-f]*/--spice-main: #ff00ff/; s/--spice-rgb-main: [0-9,]*/--spice-rgb-main: 255,0,255/' ~/.config/spicetify-dms/colors.css
```
(If the glob matches several store paths, copy from the one `readlink -f $(which spotify)` points into.)

- [ ] **Step 4: Launch the test build**

```sh
pkill -x spotify; /tmp/claude-1000/-home-otis-sitolamix/0339397a-0f23-4a6d-868c-c88af6bc6e43/scratchpad/spiced/bin/spotify &
```
Ask the user: "Is Spotify's main background magenta?" Wait for the answer.

- [ ] **Step 5: Record the result**

- Magenta: approach works, continue with Task 2.
- Not magenta: stop the plan and ask the user about the mutable spicetify-cli fallback from the spec.

- [ ] **Step 6: Revert the throwaway change**

```sh
pkill -x spotify; rm -f /tmp/claude-1000/-home-otis-sitolamix/0339397a-0f23-4a6d-868c-c88af6bc6e43/scratchpad/spiced
git checkout modules/apps/spotify.nix
rm ~/.config/spicetify-dms/colors.css
```
No commit.

---

### Task 2: `theming.matugen` module (template collector)

**Files:**
- Create: `modules/theming/matugen.nix`

**Interfaces:**
- Produces:
  - `theming.matugen.enable` (bool)
  - `theming.matugen.templates.<name>` = submodule `{ input : path; output : str; postHook : nullOr str (default null); }`
  - `theming.matugen.cursorSize` (int, default 7) — used in Task 7.
  - Writes `home-manager.users.otis.xdg.configFile."matugen/config.toml"`.

- [ ] **Step 1: Write the eval check that should fail**

```sh
nix eval --raw .#nixosConfigurations.omnibook.config.home-manager.users.otis.xdg.configFile.\"matugen/config.toml\".text
```
Expected now: error `attribute 'matugen/config.toml' missing`.

- [ ] **Step 2: Create the module**

`modules/theming/matugen.nix`:

```nix
{ config, lib, ... }:
let
  cfg = config.theming.matugen;

  # TOML basic strings: escape backslash and double quote.
  str = s: ''"${lib.escape [ "\\" "\"" ] s}"'';

  templateSection =
    name: t:
    ''
      [templates.${name}]
      input_path = ${str "${t.input}"}
      output_path = ${str t.output}
    ''
    + lib.optionalString (t.postHook != null) ''
      post_hook = ${str t.postHook}
    '';
in
{
  options.theming.matugen = {
    enable = lib.mkEnableOption "wallpaper-driven colours through DankMaterialShell's matugen run";

    templates = lib.mkOption {
      default = { };
      description = ''
        Matugen user templates. Each application module declares its own
        template next to itself; this module only collects them into
        ~/.config/matugen/config.toml, whose [templates] section DMS appends
        to its own matugen run (runUserMatugenTemplates, see
        modules/desktop/dms/theme.nix). So every template re-renders whenever
        the wallpaper changes, not on rebuild.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            input = lib.mkOption {
              type = lib.types.path;
              description = "Template file, using {{colors.*}} / {{dank16.*}} tokens.";
            };
            output = lib.mkOption {
              type = lib.types.str;
              description = "Absolute path matugen writes the rendered file to.";
            };
            postHook = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Shell command matugen runs after writing this template.";
            };
          };
        }
      );
    };

    cursorSize = lib.mkOption {
      type = lib.types.int;
      default = 7;
      description = ''
        Cursor size, logical/unscaled (same unit as niri's
        cursor.xcursor-size), so it does not grow with output scale. HiDPI
        hosts override it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # DMS only reads the [config] and [templates] sections of this file.
    # [config] stays empty: DMS supplies its own.
    home.extraOptions.xdg.configFile."matugen/config.toml".text = ''
      [config]

      [templates]
    ''
    + lib.concatStrings (lib.mapAttrsToList templateSection cfg.templates);
  };
}
```

Note: `[templates]` followed by `[templates.<name>]` tables is valid TOML, and DMS's `extractTOMLSection(data, "[templates]", "")` takes everything from `[templates]` to the end of the file.

- [ ] **Step 3: Enable it from the desktop suite**

In `modules/suites/desktop.nix`, next to `theming.stylix.enable = true;`, add `theming.matugen.enable = true;` (stylix stays until Task 7).

- [ ] **Step 4: Run the eval check**

Same command as Step 1. Expected output:
```
[config]

[templates]
```

- [ ] **Step 5: Format, check, lint**

```sh
just fmt && just check
nix shell nixpkgs#statix nixpkgs#deadnix --command sh -c 'statix check .; deadnix modules/ hosts/ themes/ flake/ flake.nix'
```
Expected: all clean.

- [ ] **Step 6: Commit**

```sh
git add modules/theming/matugen.nix modules/suites/desktop.nix
git commit -m "feat(theming): add theming.matugen, a collector for matugen user templates

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01QaJ4aPtcZ2XQDY8iDdAWeH"
```

---

### Task 3: Obsidian snippet from a matugen template

**Files:**
- Create: `modules/apps/obsidian/_lib/matugen-css.nix`
- Modify: `modules/apps/obsidian/default.nix` (the `let` block from `theme = …` through `themeCss`, the `appearanceScript`, and the `install -m644 "${themeCss}"` line)

**Interfaces:**
- Consumes: `theming.matugen.templates` (Task 2).
- Produces: `theming.matugen.templates.obsidian` rendering to `${cfg.vault}/.obsidian/snippets/sitolamix.css`.

- [ ] **Step 1: Failing eval check**

```sh
nix eval --raw .#nixosConfigurations.omnibook.config.home-manager.users.otis.xdg.configFile.\"matugen/config.toml\".text | grep -c 'templates.obsidian'
```
Expected: `0`.

- [ ] **Step 2: Create the template builder**

`modules/apps/obsidian/_lib/matugen-css.nix` — a Nix function returning the template text. Fonts and callout names are Nix data; every colour is a matugen token.

```nix
# The Obsidian CSS snippet as a matugen template. Nix fills in what is
# static (font names, the callout list); matugen fills every colour from the
# wallpaper whenever DMS regenerates its scheme. Imported by ../default.nix;
# lives under _lib so import-tree skips it.
{ lib, fonts }:
let
  c = role: "{{colors.${role}.default.hex}}";
  d = n: "{{dank16.color${toString n}.default.hex}}";
  rgbOf = prefix: "{{${prefix}.default.red}}, {{${prefix}.default.green}}, {{${prefix}.default.blue}}";
  role = r: "colors.${r}";
  ansi = n: "dank16.color${toString n}";

  headings = [
    (c "primary")
    (c "secondary")
    (c "tertiary")
    (d 6)
    (d 2)
    (c "on_surface_variant")
  ];

  # Same hue families as the old catppuccin table: statements blue-ish,
  # constructions in the accent, proofs deliberately quiet.
  callouts = {
    theorem = ansi 4;
    lemma = ansi 12;
    proposition = ansi 14;
    corollary = ansi 6;
    claim = ansi 12;
    conjecture = role "tertiary";
    hypothesis = role "tertiary";
    assumption = role "tertiary";
    axiom = ansi 13;
    definition = role "primary";
    proof = role "outline";
    solution = role "outline";
    example = ansi 2;
    exercise = ansi 11;
    remark = role "on_surface_variant";
    note = ansi 4;
    info = ansi 14;
    tip = ansi 6;
    success = ansi 2;
    question = ansi 3;
    warning = ansi 11;
    danger = role "error";
    bug = role "error";
    quote = role "tertiary";
    abstract = ansi 6;
  };

  headingVars = lib.concatStringsSep "\n" (
    lib.imap1 (i: v: "  --h${toString i}-color: ${v};") headings
  );

  # Two selectors per entry: Obsidian's own callouts key off data-callout;
  # math-booster re-renders its environments as .theorem-callout-<env> and
  # drops that attribute. !important because math-booster pins
  # --callout-color from a :has() rule no snippet selector can outrank.
  calloutRules = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: prefix: ''
      .callout[data-callout="${name}"],
      .theorem-callout.theorem-callout-${name} { --callout-color: ${rgbOf prefix} !important; }'') callouts
  );
in
''
  /* Rendered by matugen from modules/apps/obsidian/_lib/matugen-css.nix whenever
     the DMS wallpaper changes. Do not edit: the next wallpaper change
     overwrites it. Add a second snippet next to it for personal tweaks. */
  .theme-dark,
  .theme-light {
    --font-text-theme: ${fonts.serif};
    --font-interface-theme: ${fonts.sansSerif};
    --font-monospace-theme: ${fonts.monospace};

    --accent-h: {{colors.primary.default.hue}};
    --accent-s: {{colors.primary.default.saturation}}%;
    --accent-l: {{colors.primary.default.lightness}}%;

    --background-primary: ${c "surface"};
    --background-primary-alt: ${c "surface_container_low"};
    --background-secondary: ${c "surface_container_low"};
    --background-secondary-alt: ${c "surface_container_lowest"};
    --background-modifier-border: ${c "surface_container_high"};
    --background-modifier-border-hover: ${c "surface_container_highest"};
    --background-modifier-border-focus: ${c "primary"};
    --background-modifier-hover: ${c "surface_container_high"};
    --background-modifier-active-hover: ${c "surface_container_highest"};
    --background-modifier-form-field: ${c "surface_container_low"};
    --background-modifier-error: ${c "error"};
    --background-modifier-success: ${d 2};

    --text-normal: ${c "on_surface"};
    --text-muted: ${c "on_surface_variant"};
    --text-faint: ${c "outline"};
    --text-on-accent: ${c "on_primary"};
    --text-error: ${c "error"};
    --text-success: ${d 2};
    --text-accent: ${c "primary"};
    --text-accent-hover: ${c "tertiary"};
    --text-selection: ${c "surface_container_highest"};
    --text-highlight-bg: ${c "surface_container_highest"};

    --link-color: ${c "secondary"};
    --link-color-hover: ${c "tertiary"};
    --link-unresolved-color: ${c "error"};
    --link-external-color: ${c "secondary"};

    --interactive-normal: ${c "surface_container_low"};
    --interactive-hover: ${c "surface_container_high"};
    --interactive-accent: ${c "primary"};
    --interactive-accent-hover: ${c "tertiary"};

    --divider-color: ${c "surface_container_high"};
    --titlebar-background: ${c "surface_container_low"};
    --titlebar-background-focused: ${c "surface_container_low"};
    --tab-text-color-focused-active: ${c "primary"};

    --code-background: ${c "surface_container_low"};
    --code-normal: ${d 9};
    --code-comment: ${c "outline"};

    --tag-color: ${d 6};
    --tag-background: ${c "surface_container_low"};

    --blockquote-border-color: ${c "primary"};
    --table-header-background: ${c "surface_container_low"};
    --table-row-alt-background: ${c "surface_container_low"};

    --checkbox-color: ${c "primary"};
    --checkbox-color-hover: ${c "tertiary"};
    --checkbox-marker-color: ${c "on_primary"};

    --scrollbar-bg: ${c "surface"};
    --scrollbar-thumb-bg: ${c "surface_container_high"};
    --scrollbar-active-thumb-bg: ${c "surface_container_highest"};

  ${headingVars}
  }

  /* math-booster hard-sets the font to "CMU Serif, Times" from the same
     unbeatable rule. Take it back, so the whole vault stays on one typeface. */
  .theorem-callout {
    font-family: var(--font-text) !important;
    /* Its "Framed" style draws a border with no colour, so every environment
       ends up the same grey. Paint it from the environment's own accent. */
    border-color: rgba(var(--callout-color), 0.5) !important;
  }

  .theorem-callout .theorem-callout-main-title {
    color: rgb(var(--callout-color));
  }

  /* MathJax inherits colour from the text around it, which is what you want
     inside a callout. */
  .math { color: inherit; }

  ${calloutRules}
''
```

- [ ] **Step 3: Wire it in `default.nix`**

In `modules/apps/obsidian/default.nix`:

1. Delete the `let` bindings `theme`, `ob`, `swatch`, `hexDigits`, `byteAt`, `rgb`, `headingVars`, `calloutRules`, `themeCss` and their comments.
2. Add to the module's top-level `config = lib.mkIf cfg.enable { … }` (NixOS level, beside `home.extraOptions`):

```nix
theming.matugen.templates.obsidian = {
  input = builtins.toFile "obsidian-sitolamix.css" (
    import ./_lib/matugen-css.nix {
      inherit lib;
      fonts = {
        serif = lib.head config.fonts.fontconfig.defaultFonts.serif;
        sansSerif = lib.head config.fonts.fontconfig.defaultFonts.sansSerif;
        monospace = lib.head config.fonts.fontconfig.defaultFonts.monospace;
      };
    }
  );
  # Written straight into the vault. The snippet is derived entirely from
  # the wallpaper, so rebuilds no longer touch it.
  output = "${cfg.vault}/.obsidian/snippets/sitolamix.css";
};
```

The module header must take `config` and `lib` (it already does).

3. In `appearanceScript`, replace the jq program and args with (the accent now comes from the snippet's `--accent-h/s/l`, and the theme is always dark):

```nix
appearanceScript = ''
  appearance="$cfgdir/appearance.json"
  [ -e "$appearance" ] || printf '%s' '{}' > "$appearance"
  ${pkgs.jq}/bin/jq \
    '.theme = "obsidian"
     | del(.accentColor)
     | .enabledCssSnippets = ((.enabledCssSnippets // []) + ["sitolamix"] | unique)' \
    "$appearance" > "$appearance.tmp"
  mv "$appearance.tmp" "$appearance"
'';
```

Update its comment: the base theme is always dark (`obsidian`) because the matugen scheme is always dark; `accentColor` is removed because a static hex there would override the snippet's wallpaper accent.

4. Delete the line `install -m644 "${themeCss}" "$cfgdir/snippets/sitolamix.css"` from `activation.obsidianPlugins`. Keep `install -d "$cfgdir/snippets"`.


- [ ] **Step 4: Eval check passes and template renders**

```sh
nix eval --raw .#nixosConfigurations.omnibook.config.home-manager.users.otis.xdg.configFile.\"matugen/config.toml\".text
```
Expected: contains `[templates.obsidian]` with an `input_path` in the store and `output_path = "/home/otis/Documents/uni/.obsidian/snippets/sitolamix.css"`.

Render it with a sample colour to prove the tokens are valid. Bare matugen has no dank16, so feed a fake one. Run from `/home/otis/sitolamix`:

```sh
S=/tmp/claude-1000/-home-otis-sitolamix/0339397a-0f23-4a6d-868c-c88af6bc6e43/scratchpad
IN=$(nix eval --raw .#nixosConfigurations.omnibook.config.theming.matugen.templates.obsidian.input)
python3 -c 'import json; c={"default":{"hex":"#88c0d0","hex_stripped":"88c0d0","red":"136","green":"192","blue":"208","hue":"193"}}; print(json.dumps({"dank16":{f"color{i}":c for i in range(16)}}))' > $S/dank16.json
printf "[config]\n[templates.t]\ninput_path = '%s'\noutput_path = '%s/render.out'\n" "$IN" "$S" > $S/c.toml
nix run nixpkgs#matugen -- color hex '#7aa2f7' -c $S/c.toml -m dark --import-json $S/dank16.json
grep -c '{{' $S/render.out; grep -m3 'background-primary\|callout-color' $S/render.out
```
Expected: `0` unrendered `{{` (grep exits 1), and real `#…` / `r, g, b` values. Later tasks reuse this recipe with a different template name in `templates.<name>.input`.

- [ ] **Step 5: Format, check, lint** (same commands as Task 2 Step 5). Expected clean.

- [ ] **Step 6: Commit**

```sh
git add modules/apps/obsidian
git commit -m "feat(obsidian): render the vault snippet from a matugen template

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01QaJ4aPtcZ2XQDY8iDdAWeH"
```

---

### Task 4: Anki ReColor colours from a matugen template

**Files:**
- Create: `modules/apps/anki/_lib/recolor-template.nix`
- Modify: `modules/apps/anki/_lib/default.nix` (`theme` arg, `resolveSwatch`, `recolorColors`, `recolorMetaFile`, `themedFiles` handling, header comment)
- Modify: `modules/apps/anki/default.nix` (`theme` binding, `themedFiles`, add template, QT_PLUGIN_PATH comment)

**Interfaces:**
- Consumes: `theming.matugen.templates` (Task 2).
- Produces:
  - `theming.matugen.templates.anki-recolor` → `/home/otis/.local/state/sitolamix/anki-recolor.json`, `postHook` runs `recolorApply`.
  - `ankiAddons.recolorApply` — a `pkgs.writeShellScript` taking no args; merges the colours file (if present) into `~/.local/share/Anki2/addons21/688199788/meta.json` (if present).
  - `ankiAddons.recolorBaseMeta` — Nix-generated meta.json with dark slot = light slot.

- [ ] **Step 1: Failing eval check**

```sh
nix eval --raw .#nixosConfigurations.omnibook.config.home-manager.users.otis.xdg.configFile.\"matugen/config.toml\".text | grep -c 'anki-recolor'
```
Expected `0`.

- [ ] **Step 2: Create the template builder**

`modules/apps/anki/_lib/recolor-template.nix`:

```nix
# ReColor's dark-mode colours as a matugen template: a flat JSON object of
# key -> hex. ./default.nix's recolorApply merges it into the dark slot of
# ReColor's meta.json. Structural keys map to Material 3 roles; keys whose
# meaning is a hue (flags, card states) map to dank16, the harmonised ANSI
# palette DMS derives from the same scheme.
{ lib, keys }:
let
  c = role: "{{colors.${role}.default.hex}}";
  d = n: "{{dank16.color${toString n}.default.hex}}";

  map' = {
    ACCENT_CARD = c "secondary";
    ACCENT_DANGER = c "error";
    ACCENT_NOTE = d 2;
    BORDER = c "outline_variant";
    BORDER_FOCUS = c "primary";
    BORDER_STRONG = c "outline";
    BORDER_SUBTLE = c "surface_container_high";
    BUTTON_BG = c "surface_container_high";
    BUTTON_DISABLED = c "surface_container_high";
    BUTTON_HOVER = c "surface_container_highest";
    BUTTON_HOVER_BORDER = c "outline";
    BUTTON_PRIMARY_BG = c "primary_container";
    BUTTON_PRIMARY_DISABLED = c "surface_container_highest";
    BUTTON_PRIMARY_GRADIENT_END = c "primary_container";
    BUTTON_PRIMARY_GRADIENT_START = c "primary";
    CANVAS = c "surface";
    CANVAS_CODE = c "surface_container_low";
    CANVAS_ELEVATED = c "surface_container_low";
    CANVAS_GLASS = "{{colors.surface_container_low.default.hex_stripped}}66";
    CANVAS_INSET = c "surface_container_lowest";
    CANVAS_OVERLAY = c "surface_container_low";
    FG = c "on_surface";
    FG_DISABLED = c "outline";
    FG_FAINT = c "outline";
    FG_LINK = c "primary";
    FG_SUBTLE = c "on_surface_variant";
    FLAG_1 = d 1;
    FLAG_2 = d 9;
    FLAG_3 = d 2;
    FLAG_4 = d 4;
    FLAG_5 = d 5;
    FLAG_6 = d 6;
    FLAG_7 = d 13;
    HIGHLIGHT_BG = c "secondary_container";
    HIGHLIGHT_FG = c "on_secondary_container";
    SCROLLBAR_BG = c "surface";
    SCROLLBAR_BG_ACTIVE = c "surface_container_high";
    SCROLLBAR_BG_HOVER = c "surface";
    SELECTED_BG = c "secondary_container";
    SELECTED_FG = c "on_secondary_container";
    SHADOW = c "shadow";
    SHADOW_FOCUS = c "primary";
    SHADOW_INSET = c "surface_container_lowest";
    SHADOW_SUBTLE = c "surface_container_low";
    STATE_BURIED = c "outline";
    STATE_LEARN = d 1;
    STATE_MARKED = d 3;
    STATE_NEW = d 4;
    STATE_REVIEW = d 2;
    STATE_SUSPENDED = c "on_surface_variant";
  };

  # Fail at eval time if ReColor's schema gains or loses a key, rather than
  # silently leaving a slot on its light value.
  missing = lib.subtractLists (lib.attrNames map') keys;
  extra = lib.subtractLists keys (lib.attrNames map');
in
assert lib.assertMsg (missing == [ ]) "anki recolor template: no token for ${toString missing}";
assert lib.assertMsg (extra == [ ]) "anki recolor template: unknown ReColor keys ${toString extra}";
builtins.toJSON map'
```

Before writing, confirm the key list matches: `jq -r 'keys[]' modules/apps/anki/_lib/recolor-schema.json` must equal the attribute names above. If it differs, the asserts will say which.

- [ ] **Step 3: Rework `_lib/default.nix`**

1. Replace the header paragraph starting `# ReColor's colors are theme-driven…` with:

```nix
# ReColor's dark-mode colours follow the wallpaper. Nix writes a base
# meta.json (labels, light values and CSS var names from recolor-schema.json,
# dark slot = light value) on every activation; recolorApply then fills the
# dark slot from the colours file matugen renders from ./recolor-template.nix.
# matugen runs recolorApply as its post-hook on every wallpaper change, and
# activation runs it again so a rebuild does not reset Anki to the light
# values. Anki reads the file at startup, so a new wallpaper shows on the
# next Anki start.
```

2. Change the argument set from `{ pkgs, lib, theme }:` to `{ pkgs, lib }:`.
3. Delete `resolveSwatch` and `recolorColors`. Replace `recolorMetaFile` with:

```nix
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
```

4. Export them: change `inherit addons seededIds recolorMetaFile;` to `inherit addons seededIds recolorBaseMeta recolorTemplate recolorApply recolorColorsFile;`.
5. In `mkActivationScript`, update the `themedFiles` doc comment to: `installs a Nix-generated meta.json verbatim on every run, then runs recolorApply` and change the final concatenation to:

```nix
    + lib.concatStrings (map deployThemedFile themedFiles)
    + lib.optionalString (themedFiles != [ ]) ''
      ${recolorApply}
    '';
```

- [ ] **Step 4: Rework `anki/default.nix`**

1. Delete the `theme = …` binding and its comment; change `import ./_lib { inherit pkgs lib theme; }` to `import ./_lib { inherit pkgs lib; }`.
2. `themedFiles = [ { id = "688199788"; file = ankiAddons.recolorBaseMeta; } ];`
3. The template must be declared at NixOS level, but `ankiAddons` needs home-manager's `pkgs`. NixOS `pkgs` is the same package set here (`home-manager.useGlobalPkgs`), so at the top of the file take `pkgs` in the module args (`{ config, lib, pkgs, ... }:`) and add to `config = lib.mkIf cfg.enable { … }`:

```nix
theming.matugen.templates.anki-recolor =
  let
    ankiAddons = import ./_lib { inherit pkgs lib; };
  in
  {
    input = ankiAddons.recolorTemplate;
    output = "/home/otis/.local/state/sitolamix/anki-recolor.json";
    postHook = "${ankiAddons.recolorApply}";
  };
```

4. Rewrite the QT_PLUGIN_PATH paragraph in the `pkgs.anki` comment: replace `(kvantum + qt6ct, which stylix's own Qt support puts there — no file in this repo sets them)` with `(qt6ct and qt5ct, which modules/theming/matugen.nix sets up)`. Leave the rest of the reasoning (a style plugin built against a second qtbase segfaults Anki) intact.

- [ ] **Step 5: Verify**

```sh
nix eval --raw .#nixosConfigurations.omnibook.config.home-manager.users.otis.xdg.configFile.\"matugen/config.toml\".text | grep -A3 anki-recolor
```
Expected: `input_path`, `output_path = "/home/otis/.local/state/sitolamix/anki-recolor.json"`, `post_hook = "/nix/store/…-anki-recolor-apply"`.

Render the template with the Task 3 Step 4 recipe using `templates.anki-recolor.input` (quote it: `templates.\"anki-recolor\".input`), then `jq 'length' $S/render.out` — expected: the key count of `recolor-schema.json` (`jq 'length' modules/apps/anki/_lib/recolor-schema.json`). Copy it: `cp $S/render.out $S/anki.out`.

Then test the merge on a copy:
```sh
cp ~/.local/share/Anki2/addons21/688199788/meta.json $S/meta.json
# run the jq program from recolorApply against $S/meta.json with anki.out
jq --slurpfile c $S/anki.out '.config.colors |= with_entries(.value[2] = ($c[0][.key] // .value[2]))' $S/meta.json | jq '.config.colors.CANVAS'
```
Expected: slot 2 is the rendered surface colour.

- [ ] **Step 6: Format, check, lint.** Expected clean.

- [ ] **Step 7: Commit**

```sh
git add modules/apps/anki
git commit -m "feat(anki): take ReColor's dark colours from a matugen template

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01QaJ4aPtcZ2XQDY8iDdAWeH"
```

---

### Task 5: Spotify colours from a matugen template

Only if Task 1 answered "magenta".

**Files:**
- Move: `modules/apps/spotify.nix` → `modules/apps/spotify/default.nix` (`git mv`)
- Create: `modules/apps/spotify/colors.css`

**Interfaces:**
- Consumes: `theming.matugen.templates` (Task 2).
- Produces: `theming.matugen.templates.spotify` → `/home/otis/.config/spicetify-dms/colors.css`.

- [ ] **Step 1: Move the module**

```sh
git mv modules/apps/spotify.nix modules/apps/spotify/default.nix
```

- [ ] **Step 2: Create the template**

`modules/apps/spotify/colors.css` — same variable set spicetify generates from `color.ini`:

```css
:root {
    --spice-text: {{colors.on_surface.default.hex}};
    --spice-subtext: {{colors.on_surface_variant.default.hex}};
    --spice-main: {{colors.surface.default.hex}};
    --spice-main-elevated: {{colors.surface_container.default.hex}};
    --spice-main-secondary: {{colors.surface_container_high.default.hex}};
    --spice-highlight: {{colors.surface_container_high.default.hex}};
    --spice-highlight-elevated: {{colors.surface_container_highest.default.hex}};
    --spice-sidebar: {{colors.surface_container_low.default.hex}};
    --spice-player: {{colors.surface_container_low.default.hex}};
    --spice-card: {{colors.surface_container.default.hex}};
    --spice-shadow: {{colors.shadow.default.hex}};
    --spice-selected-row: {{colors.on_surface.default.hex}};
    --spice-button: {{colors.primary.default.hex}};
    --spice-button-active: {{colors.primary.default.hex}};
    --spice-button-secondary: {{colors.secondary.default.hex}};
    --spice-button-disabled: {{colors.outline.default.hex}};
    --spice-nav-active: {{colors.primary.default.hex}};
    --spice-nav-active-text: {{colors.on_primary.default.hex}};
    --spice-tab-active: {{colors.secondary_container.default.hex}};
    --spice-play-button: {{colors.primary.default.hex}};
    --spice-playback-bar: {{colors.primary.default.hex}};
    --spice-notification: {{colors.secondary.default.hex}};
    --spice-notification-error: {{colors.error.default.hex}};
    --spice-misc: {{colors.tertiary.default.hex}};

    --spice-rgb-text: {{colors.on_surface.default.red}},{{colors.on_surface.default.green}},{{colors.on_surface.default.blue}};
    --spice-rgb-subtext: {{colors.on_surface_variant.default.red}},{{colors.on_surface_variant.default.green}},{{colors.on_surface_variant.default.blue}};
    --spice-rgb-main: {{colors.surface.default.red}},{{colors.surface.default.green}},{{colors.surface.default.blue}};
    --spice-rgb-main-elevated: {{colors.surface_container.default.red}},{{colors.surface_container.default.green}},{{colors.surface_container.default.blue}};
    --spice-rgb-main-secondary: {{colors.surface_container_high.default.red}},{{colors.surface_container_high.default.green}},{{colors.surface_container_high.default.blue}};
    --spice-rgb-highlight: {{colors.surface_container_high.default.red}},{{colors.surface_container_high.default.green}},{{colors.surface_container_high.default.blue}};
    --spice-rgb-highlight-elevated: {{colors.surface_container_highest.default.red}},{{colors.surface_container_highest.default.green}},{{colors.surface_container_highest.default.blue}};
    --spice-rgb-sidebar: {{colors.surface_container_low.default.red}},{{colors.surface_container_low.default.green}},{{colors.surface_container_low.default.blue}};
    --spice-rgb-player: {{colors.surface_container_low.default.red}},{{colors.surface_container_low.default.green}},{{colors.surface_container_low.default.blue}};
    --spice-rgb-card: {{colors.surface_container.default.red}},{{colors.surface_container.default.green}},{{colors.surface_container.default.blue}};
    --spice-rgb-shadow: {{colors.shadow.default.red}},{{colors.shadow.default.green}},{{colors.shadow.default.blue}};
    --spice-rgb-selected-row: {{colors.on_surface.default.red}},{{colors.on_surface.default.green}},{{colors.on_surface.default.blue}};
    --spice-rgb-button: {{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}};
    --spice-rgb-button-active: {{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}};
    --spice-rgb-button-secondary: {{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}};
    --spice-rgb-button-disabled: {{colors.outline.default.red}},{{colors.outline.default.green}},{{colors.outline.default.blue}};
    --spice-rgb-nav-active: {{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}};
    --spice-rgb-nav-active-text: {{colors.on_primary.default.red}},{{colors.on_primary.default.green}},{{colors.on_primary.default.blue}};
    --spice-rgb-tab-active: {{colors.secondary_container.default.red}},{{colors.secondary_container.default.green}},{{colors.secondary_container.default.blue}};
    --spice-rgb-play-button: {{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}};
    --spice-rgb-playback-bar: {{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}};
    --spice-rgb-notification: {{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}};
    --spice-rgb-notification-error: {{colors.error.default.red}},{{colors.error.default.green}},{{colors.error.default.blue}};
    --spice-rgb-misc: {{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}};
}
```

- [ ] **Step 3: Rewire the module**

In `modules/apps/spotify/default.nix`:

1. Option description: `"Spotify with spicetify (wallpaper-themed + extensions)"`.
2. Add at NixOS level inside `config = lib.mkIf cfg.enable { … }`:

```nix
theming.matugen.templates.spotify = {
  input = ./colors.css;
  output = "/home/otis/.config/spicetify-dms/colors.css";
};
```

3. Delete the `stylix.targets.spicetify.enable = false;` line and its comment block.
4. Replace `colorScheme = "custom";` and the whole `customColorScheme = …` block with:

```nix
# Colours follow the wallpaper. spicetify bakes a colour scheme into the
# store build at `spicetify apply` time, which no runtime change can reach —
# but the result loads its colours from a separate Apps/xpui/colors.css. So
# the build is left with sleek's default scheme and that one file is
# replaced, after apply, by a link out of the store to the file matugen
# renders from ./colors.css (theming.matugen.templates.spotify above).
# Spotify reads it at startup: a new wallpaper shows on the next launch.
# Checked 2026-09-15 that Spotify's Chromium follows the link. Drop this if
# spicetify-nix ever grows a runtime colour file of its own.
spotifyPackage = pkgs.spotify.overrideAttrs (old: {
  postFixup = (old.postFixup or "") + ''
    ln -sf /home/otis/.config/spicetify-dms/colors.css $out/share/spotify/Apps/xpui/colors.css
  '';
});
```

`config` in the home-manager function header may now be unused — remove it if deadnix complains.

- [ ] **Step 4: Verify**

```sh
nix build --no-link --print-out-paths .#nixosConfigurations.omnibook.config.home-manager.users.otis.programs.spicetify.spicedSpotify | xargs -I{} readlink {}/share/spotify/Apps/xpui/colors.css
```
Expected: `/home/otis/.config/spicetify-dms/colors.css`.

Render with the Task 3 Step 4 recipe using `templates.spotify.input`; expect `grep -c '{{' $S/render.out` = `0`.

- [ ] **Step 5: Format, check, lint.** Expected clean.

- [ ] **Step 6: Commit**

```sh
git add modules/apps/spotify
git commit -m "feat(spotify): link spicetify's colors.css to a matugen-rendered file

Verified by hand that Spotify's Chromium follows the out-of-store symlink.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01QaJ4aPtcZ2XQDY8iDdAWeH"
```

---

### Task 6: Neovim DMS colourscheme (base46 input)

**Files:**
- Modify: `flake.nix` (new `base46-dms` input)
- Modify: `modules/apps/neovim.nix`

**Interfaces:**
- Produces: `programs.neovim.plugins` contains a `base46` built from `inputs.base46-dms`; init runs `colorscheme dms` when present. Task 7 flips `matugenTemplateNeovim = true`.

- [ ] **Step 1: Add the input**

In `flake.nix`, after the `dms-take-a-break` input:

```nix
    # AvengeMedia/base46 — DMS's fork of NvChad's base46 colour engine. DMS's
    # neovim matugen template (~/.config/nvim/colors/dms.lua) requires it and
    # checks for its `_DMS_SUPPORT` marker, so nixpkgs' vimPlugins.base46
    # (upstream NvChad, no harmonise API) does not work. flake=false: it is a
    # plain plugin tree, built with vimUtils in modules/apps/neovim.nix.
    base46-dms = {
      url = "github:AvengeMedia/base46";
      flake = false;
    };
```

Run `nix flake lock` (adds only this entry). Check `git diff flake.lock` shows one new node and no other rev changes.

Confirm the marker exists: `grep -rn _DMS_SUPPORT $(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.base46-dms.outPath')/lua | head -1`. Expected: one hit. If the repo lives on another branch, set `url = "github:AvengeMedia/base46/<branch>"` and re-lock.

- [ ] **Step 2: Wire the plugin**

`modules/apps/neovim.nix` — module args gain `inputs`; inside `programs.neovim`:

```nix
plugins = [
  (pkgs.vimUtils.buildVimPlugin {
    pname = "base46-dms";
    version = inputs.base46-dms.shortRev or "unstable";
    src = inputs.base46-dms;
    # plugin runtime is loaded lazily by the colorscheme; nothing to require-check.
    doCheck = false;
  })
];

# DMS's matugen renders colors/dms.lua on every wallpaper change and the
# file hot-reloads itself. Before DMS has run once the file does not exist,
# so a bare `colorscheme dms` would error on every start; pcall keeps nvim
# quiet until it appears.
initLua = ''
  pcall(vim.cmd.colorscheme, "dms")
'';
```

If the home-manager in `flake.lock` does not have `programs.neovim.initLua`, use `extraLuaConfig` instead (check with `nix eval .#nixosConfigurations.omnibook.options.home-manager.users.type.getSubOptions [] --apply 'o: o.programs.neovim ? initLua'`, or just try `just check`).

If `buildVimPlugin` fails `nvimRequireCheck`, add `nvimSkipModules = [ … ]` for the modules it names, with a comment saying they need a running base46 cache.

- [ ] **Step 3: Format, check, lint.** Expected clean.

- [ ] **Step 4: Commit**

```sh
git add flake.nix flake.lock modules/apps/neovim.nix
git commit -m "feat(neovim): add DMS's base46 fork for the matugen colorscheme

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01QaJ4aPtcZ2XQDY8iDdAWeH"
```

---

### Task 7: Remove stylix; turn DMS dynamic theming on

This is the switchover. All remaining stylix references go in one commit, because `just check` cannot pass with half of them.

**Files:**
- Delete: `modules/theming/stylix.nix`, `themes/default.nix`, `themes/catppuccin-mocha.nix`
- Modify: `flake.nix`, `modules/theming/matugen.nix`, `modules/suites/desktop.nix`, `hosts/omnibook/default.nix`, `modules/desktop/dms/{theme,default,bar,niri}.nix`, `modules/desktop/niri/appearance.nix`, `modules/desktop/niri/default.nix`, `modules/apps/{ghostty,zed,vscode,starship,cli,tmux,yazi}.nix`, `modules/system/fonts.nix`, `modules/system/nixpkgs-stable.nix`

**Interfaces:**
- Consumes: `theming.matugen.cursorSize` (Task 2).

- [ ] **Step 1: Delete stylix and the palette**

```sh
git rm modules/theming/stylix.nix themes/default.nix themes/catppuccin-mocha.nix
```

In `flake.nix`: delete the `stylix = { … };` input block; change `description` to `"sitolamix — enable-options NixOS: niri + DankMaterialShell, themed from the wallpaper"`. Run `nix flake lock` and confirm `git diff flake.lock` only removes stylix and its now-unused transitive nodes.

- [ ] **Step 2: Non-colour settings in `theming.matugen`**

In `modules/theming/matugen.nix`, take `pkgs` in the args and extend `config = lib.mkIf cfg.enable { … }`:

```nix
# Qt: qt5ct/qt6ct as the platform theme, so DMS's qtct colour templates
# apply. home-manager's `qt` module only sets the env var and installs the
# packages here; it must not own qt5ct.conf/qt6ct.conf, which DMS's
# scripts/qt.sh edits in place.
qt = {
  enable = true;
  platformTheme = "qt5ct";
};

home.extraOptions =
  { pkgs, ... }:
  {
    xdg.configFile."matugen/config.toml".text = …; # keep the existing definition here

    home.pointerCursor = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = cfg.cursorSize;
      # gtk.enable would turn on home-manager's gtk module; the cursor is set
      # through dconf below instead so nothing here owns gtk.css.
      x11.enable = true;
    };

    home.packages = [
      pkgs.adw-gtk3
      pkgs.whitesur-icon-theme
    ];

    # GTK theme, icons and cursor through gsettings rather than home-manager's
    # gtk module. That module writes gtk-3.0/gtk.css and gtk-4.0/gtk.css as
    # store symlinks, and DMS's scripts/gtk.sh refuses to add its
    # `@import url("dank-colors.css")` to a symlink it did not create — which
    # is exactly the line that carries the wallpaper colours into GTK apps.
    # adw-gtk3-dark is the base DMS copies to ~/.local/share/themes and patches.
    dconf.settings."org/gnome/desktop/interface" = {
      gtk-theme = "adw-gtk3-dark";
      icon-theme = "WhiteSur-dark";
      cursor-theme = "Bibata-Modern-Classic";
      cursor-size = cfg.cursorSize;
      color-scheme = "prefer-dark";
      font-name = "${lib.head config.fonts.fontconfig.defaultFonts.sansSerif} 10";
      monospace-font-name = "${lib.head config.fonts.fontconfig.defaultFonts.monospace} 10";
    };
  };
```

Merge the two `home.extraOptions` definitions into the single function above (the `matugen/config.toml` text moves inside it). Check the NixOS `qt.platformTheme` enum accepts `"qt5ct"` (`nix eval .#nixosConfigurations.omnibook.options.qt.platformTheme.type.description`); if it only accepts other names, set it to whatever value maps to `QT_QPA_PLATFORMTHEME=qt5ct` and note that in the comment. Also add `pkgs.kdePackages.qt6ct` and `pkgs.libsForQt5.qt5ct` to `environment.systemPackages` if the NixOS qt module does not install them (check `nix eval` of `environment.systemPackages` names for `qt6ct`).

Stylix also installed these icon names under `WhiteSur`; check `ls $(nix build --no-link --print-out-paths nixpkgs#whitesur-icon-theme)/share/icons` and use the dark variant's exact directory name.

- [ ] **Step 3: Suite and host**

`modules/suites/desktop.nix`: delete `theming.stylix.enable = true;`; update the `mkEnableOption` text to `"niri + DankMaterialShell + wallpaper theming + kanata desktop"`.

`hosts/omnibook/default.nix`: replace `stylix.cursor.size = 16;` with `theming.matugen.cursorSize = 16;` and change `(modules/theming/stylix.nix)` in the comment above it to `(modules/theming/matugen.nix)`.

- [ ] **Step 4: DMS dynamic theme**

`modules/desktop/dms/theme.nix` — replace the whole file with:

```nix
{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.dms.enable {
    home.extraOptions.programs.dank-material-shell.settings = {
      # Colours come from the wallpaper. DMS runs matugen on every wallpaper
      # change and renders its built-in app templates plus the user templates
      # modules collect through theming.matugen.templates.
      currentThemeName = "dynamic";
      # Declared here, so a scheme picked in DMS's UI lasts only until DMS
      # restarts (settings.json is a store symlink). Try schemes live in the
      # UI, then set the winner here.
      matugenScheme = "scheme-tonal-spot";
      runUserMatugenTemplates = true;

      # neovim's template is off by default in DMS; modules/apps/neovim.nix
      # ships the base46 fork it needs.
      matugenTemplateNeovim = true;

      fontFamily = lib.head config.fonts.fontconfig.defaultFonts.sansSerif;
      monoFontFamily = lib.head config.fonts.fontconfig.defaultFonts.monospace;

      # ---- blur (niri 26.04 ext-background-effect) ----
      # (keep every existing blur line and comment from the old file here,
      # unchanged, except:)
      popupTransparency = 0.3;
      dockTransparency = 0.3;
    };
  };
}
```

Copy the blur block (`blurEnabled` through `blurredWallpaperLayer` with its comments) verbatim from the old file. In the transparency comment, delete the sentence about stylix.opacity forcing them opaque and the `mkForce`.

`modules/desktop/dms/default.nix`:
- delete `enableDynamicTheming = false;` and its comment (the option defaults to `true` and pulls in `pkgs.matugen`).
- in the `seedDmsSession` seed add `isLightMode = false;` with comment `# always dark: the matugen templates in this repo only render dark tokens.`
- delete the X-Restart-Triggers comment's mention of "theme file" only if it no longer applies (settings.json still triggers restarts; keep the mechanism).

`modules/desktop/dms/bar.nix`: replace

```nix
      # let stylix own GTK/Qt app theming; DMS shouldn't apply its own.
      gtkThemingEnabled = false;
      qtThemingEnabled = false;
```
with
```nix
      # DMS recolours GTK (adw-gtk3 + dank-colors.css) and Qt (qt5ct/qt6ct)
      # apps from the wallpaper; see modules/theming/matugen.nix.
      gtkThemingEnabled = true;
      qtThemingEnabled = true;
```

`modules/desktop/dms/niri.nix`:
- delete the `environment.DMS_DISABLE_MATUGEN = "1";` line and its comment. If `programs.niri.settings` is then only `layer-rules`, keep it.
- `filesToInclude = [ "outputs" "colors" ];` and extend the comment: `colors` is DMS's matugen-rendered focus ring, border, shadow, tab indicator and insert hint, which is why niri/appearance.nix sets no colours.

- [ ] **Step 5: niri appearance and polkit comment**

`modules/desktop/niri/appearance.nix`:
- delete `active.color` / `inactive.color` from `layout.focus-ring` (keep `enable = true;`).
- replace `overview.backdrop-color = "#${config.lib.stylix.colors.base00}";` and its comment with nothing — DMS's blurred wallpaper layer is the backdrop; niri's default is used on outputs where it does not render. If the comment's case (non-focused monitor) matters, note in the removed-lines commit message that the fallback is now niri's default grey.
- the home-manager function no longer needs `config`; change the header comment `# HM function — needs home-manager's config for stylix colors.` and the arg set accordingly (`{ lib, ... }:`).

`modules/desktop/niri/default.nix` polkit comment: replace the sentence about `stylix's QT_STYLE_OVERRIDE=kvantum` with the reason that remains — the two agents race — and drop the kvantum segfault clause, since kvantum is gone. Keep the mask.

- [ ] **Step 6: Apps**

`modules/apps/ghostty.nix`:

```nix
settings = {
  # DMS renders the wallpaper palette to ~/.config/ghostty/themes/dankcolors
  # and signals ghostty to reload. starship, tmux, yazi, btop, bat, fzf and
  # lazygit all draw with this ANSI palette, so they follow too.
  theme = "dankcolors";
  background-opacity = 0.8;
  font-family = [
    "Meslo LG S"
    "Noto Color Emoji"
  ];
  font-size = 13;
  window-padding-x = 14;
  window-padding-y = 14;
  confirm-close-surface = false;
};
```
Drop both `lib.mkForce`s and their stylix comments; keep the unpatched-Meslo comment but remove `stylix still uses the patched nerd font for other apps.` → `other apps use the patched nerd font from modules/system/fonts.nix.`

`modules/apps/zed.nix` `userSettings`:

```nix
userSettings = {
  vim_mode = true;
  # DMS renders ~/.config/zed/themes/dank-zed-theme.json from the wallpaper.
  theme = "DankShell Dark";
  buffer_font_family = "MesloLGS Nerd Font Mono";
  buffer_font_size = 20;
  ui_font_family = "DejaVu Sans";
  ui_font_size = 16;
};
```
Delete the stylix comment.

`modules/apps/vscode.nix`:
- `mutableExtensionsDir` comment: `stylix drops its generated theme extension in` → `DMS installs its wallpaper-generated theme extension (dms-theme) there`.
- replace the userSettings comment (`stylix's vscode target writes into this same option…`) with `# Theme and fonts live here now; DMS provides the theme itself as the dms-theme extension.` and add:

```nix
"workbench.colorTheme" = "Dynamic Base16 DankShell (Dark)";
"editor.fontFamily" = "MesloLGS Nerd Font Mono";
"editor.fontSize" = 20;
"terminal.integrated.fontSize" = 20;
"debug.console.fontFamily" = "MesloLGS Nerd Font Mono";
"debug.console.fontSize" = 20;
"scm.inputFontFamily" = "MesloLGS Nerd Font Mono";
"chat.editor.fontFamily" = "MesloLGS Nerd Font Mono";
"chat.editor.fontSize" = 20;
"chat.fontFamily" = "DejaVu Sans";
"markdown.preview.fontFamily" = "DejaVu Sans";
"markdown.preview.fontSize" = 20;
"notebook.markup.fontFamily" = "DejaVu Sans";
```

Confirm the theme label: after DMS has run once, `jq -r '.contributes.themes[].label' ~/.vscode/extensions/*dms-theme*/package.json`. Until then use the label from `quickshell/matugen/vsix-build/package.json` (`Dynamic Base16 DankShell (Dark)`).

`modules/apps/starship.nix`: comment becomes `# default starship prompt; its colours are ANSI names, so it follows the terminal palette ghostty takes from the wallpaper.`

`modules/apps/cli.nix`: `btop.enable = true;` becomes

```nix
btop = {
  enable = true;
  # TTY theme draws with the terminal's 16 ANSI colours, which DMS sets
  # from the wallpaper through ghostty.
  settings.color_theme = "TTY";
};
```
and add `bat.config.theme = "ansi";` to the existing `bat` block (or create `bat = { … }` if bat is enabled elsewhere — find it with `grep -rn 'bat' modules/apps/cli.nix`).

`tmux`, `yazi`, `fzf`, `lazygit`, `fish`: no change needed — their defaults use ANSI colours. Verify nothing else references stylix: `grep -rn stylix --include=*.nix .` must print nothing.

`modules/system/fonts.nix`: comment `(stylix picks its faces from these, see ../theming/stylix.nix)` → `(fontconfig defaults below; DMS, Obsidian and the GTK font read them)`.

`modules/system/nixpkgs-stable.nix`: remove `stylix` from the list in the line `quickshell, stylix and home-manager all follow…`.

- [ ] **Step 7: Check for leftovers**

```sh
grep -rn 'stylix\|themes/\|catppuccin' --include=*.nix . | grep -v 'catppuccin-grub'
grep -rnE '"#[0-9a-fA-F]{6}' --include=*.nix modules hosts
```
Expected: both empty (grub.nix's `catppuccin-grub` is allowed).

- [ ] **Step 8: Format, check, lint, build, diff**

```sh
just fmt && just check
nix shell nixpkgs#statix nixpkgs#deadnix --command sh -c 'statix check .; deadnix modules/ hosts/ flake/ flake.nix'
just build && just diff
```
Expected in the diff: `stylix`, `kvantum`, `base16-schemes` gone; `adw-gtk3`, `whitesur-icon-theme`, `matugen`, `qt6ct` present. Report anything else removed to the user.

Also evaluate gamingpc explicitly (`just check` covers both hosts; make sure it did).

- [ ] **Step 9: Commit**

```sh
git add -A
git commit -m "feat(theming)!: drop stylix, theme everything from the DMS wallpaper

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01QaJ4aPtcZ2XQDY8iDdAWeH"
```

---

### Task 8: zen, Helium and Vesktop

**Files:**
- Modify: `modules/suites/browser.nix`, `modules/apps/helium/default.nix`, `modules/suites/social.nix`

**Interfaces:**
- Consumes: DMS built-in outputs `~/.config/DankMaterialShell/zen.css`, `~/.config/vesktop/themes/dank-discord.css`.

- [ ] **Step 1: zen userChrome**

zen is a bare package in `modules/suites/browser.nix`; its profile directory is created by zen on first start, with a random name. Add to `home.extraOptions` (make it a function taking `lib` and `pkgs`):

```nix
# zen: DMS renders ~/.config/DankMaterialShell/zen.css from the wallpaper.
# zen only loads chrome/userChrome.css with the legacy stylesheet pref on,
# and profile directories are created by zen itself under a random name, so
# link into every profile that exists. A fresh machine picks this up on the
# first rebuild after zen has been started once. Drop this if zen-browser's
# flake grows a home-manager module with profile settings (then use that).
home.activation.zenDmsChrome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  for root in "$HOME/.zen" "$HOME/.config/zen"; do
    [ -d "$root" ] || continue
    for profile in "$root"/*/; do
      [ -e "$profile/prefs.js" ] || continue
      run mkdir -p "$profile/chrome"
      run ln -sfn "$HOME/.config/DankMaterialShell/zen.css" "$profile/chrome/userChrome.css"
      if ! grep -q 'legacyUserProfileCustomizations.stylesheets' "$profile/user.js" 2>/dev/null; then
        run sh -c "echo 'user_pref(\"toolkit.legacyUserProfileCustomizations.stylesheets\", true);' >> '$profile/user.js'"
      fi
    done
  done
'';
```

If `$profile/chrome/userChrome.css` already exists as a regular file the user wrote, `ln -sfn` replaces it — guard: skip when it is a regular file (`[ -f "$f" ] && [ ! -L "$f" ] && continue`) and add that line.

- [ ] **Step 2: Helium GTK theme mode**

Find how the helium module handles profile state: `grep -n 'activation\|Preferences\|Local State' modules/apps/helium/default.nix`. Add a home-manager activation that merges `extensions.theme.system_theme = 1` (1 = GTK) into `~/.config/net.imput.helium/Default/Preferences` with jq, only when the file exists and Helium is not running (Chromium rewrites Preferences on exit):

```nix
# Chromium's "GTK" appearance takes its colours from the GTK theme, which
# DMS recolours from the wallpaper — there is no matugen template for
# Chromium itself. The mode is a profile pref with no policy equivalent
# (BrowserThemeColor is a single static colour), so it is merged into
# Preferences. Skipped while helium runs, because it rewrites the file on
# exit and would undo the merge.
home.activation.heliumGtkTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  prefs="$HOME/.config/net.imput.helium/Default/Preferences"
  if [ -e "$prefs" ] && ! ${pkgs.procps}/bin/pgrep -x helium >/dev/null; then
    run ${pkgs.jq}/bin/jq '.extensions.theme.system_theme = 1' "$prefs" > "$prefs.tmp"
    run mv "$prefs.tmp" "$prefs"
  fi
'';
```

Verify the profile path and the process name first: `ls ~/.config/net.imput.helium/Default/Preferences` and `pgrep -a helium`. Adjust both if they differ, and verify the key by toggling Settings > Appearance > Theme > GTK in Helium once and running `jq .extensions.theme ~/.config/net.imput.helium/Default/Preferences`.

- [ ] **Step 3: Vesktop theme**

In `modules/suites/social.nix`, add an activation that enables DMS's theme in Vesktop's app-owned settings (seed-merge, never overwrite):

```nix
# DMS renders ~/.config/vesktop/themes/dank-discord.css from the wallpaper;
# Vesktop only loads a theme listed in its own settings, which it owns and
# rewrites, so the name is merged in rather than the file written.
home.activation.vesktopDmsTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  s="$HOME/.config/vesktop/settings/settings.json"
  if [ -e "$s" ]; then
    run ${pkgs.jq}/bin/jq '.enabledThemes = ((.enabledThemes // []) + ["dank-discord.css"] | unique)' "$s" > "$s.tmp"
    run mv "$s.tmp" "$s"
  fi
'';
```
Check the real path with `ls ~/.config/vesktop/settings/` first; Vencord's settings file may be `settings/settings.json` or `settings.json`.

- [ ] **Step 4: Format, check, lint.** Expected clean.

- [ ] **Step 5: Commit**

```sh
git add modules/suites/browser.nix modules/apps/helium/default.nix modules/suites/social.nix
git commit -m "feat(theming): follow the wallpaper in zen, helium and vesktop

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01QaJ4aPtcZ2XQDY8iDdAWeH"
```

---

### Task 9: dharmx/walls

**Files:**
- Modify: `flake.nix` (`wallpapers` input), `modules/desktop/wallpapers.nix`

- [ ] **Step 1: Swap the input**

```nix
    # dharmx/walls — a plain repo of wallpaper images sorted into category
    # folders, linked into ~/Pictures/Wallpapers by
    # modules/desktop/wallpapers.nix so DMS can browse them; DMS derives every
    # colour on the desktop from the one picked. flake=false: it is images,
    # not a flake. The repo carries no licence file — it is fetched, never
    # copied into this repo. Large: GitHub reports ~3.8 GB with history.
    wallpapers = {
      url = "github:dharmx/walls";
      flake = false;
    };
```

Run `nix flake update wallpapers` (this downloads the tarball; expect minutes). Then `ls $(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.wallpapers.outPath')/nature | head`.

- [ ] **Step 2: Default from `nature/`**

In `modules/desktop/wallpapers.nix`:

```nix
  # dharmx/walls — a flake input, so the images live in the Nix store and
  # nowhere else, sorted into category folders.
  collection = inputs.wallpapers;

  # The category DMS starts in. DMS has no wallpaper-folder setting:
  # Services/WallpaperCyclingService.qml cycles the directory of the current
  # wallpaper —
  #
  #   const wallpaperDir = currentWallpaper.substring(0, currentWallpaper.lastIndexOf('/'))
  #
  # — so seeding an image inside `nature/` makes cycling cover that category.
  # Pick an image from another folder in DMS to cycle that one instead.
  category = "nature";

  # First image of the category, by natural sort. Plain readDir on a store
  # path, so no import-from-derivation; guards against an input update
  # renaming files.
  images = lib.naturalSort (
    lib.attrNames (
      lib.filterAttrs (
        name: type:
        type == "regular"
        && lib.any (ext: lib.hasSuffix ext (lib.toLower name)) [
          ".jpg"
          ".jpeg"
          ".png"
        ]
      ) (builtins.readDir "${collection}/${category}")
    )
  );
  chosen = lib.head images;
```

and `desktop.dms.initialWallpaper = "${collection}/${category}/${chosen}";`. Remove the old `default = "cat-in-clouds.png"` and the `lib.elem` fallback.

`session.json` is only seeded when missing, so the live machine keeps its current (catppuccin store path) wallpaper, which will point at a store path that is garbage-collected later. Add to the verification task a manual step to pick a new wallpaper in DMS after switching.

- [ ] **Step 3: Verify**

```sh
nix eval --raw .#nixosConfigurations.omnibook.config.desktop.dms.initialWallpaper
```
Expected: `/nix/store/…-source/nature/<file>` and `test -f` of that path succeeds.

- [ ] **Step 4: Format, check, lint.** Expected clean.

- [ ] **Step 5: Commit**

```sh
git add flake.nix flake.lock modules/desktop/wallpapers.nix
git commit -m "feat(wallpapers): replace catppuccin walls with dharmx/walls

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01QaJ4aPtcZ2XQDY8iDdAWeH"
```

---

### Task 10: Documentation

**Files:**
- Modify: `CLAUDE.md`, `README.md`, `docs/design/specs/2026-09-15-dms-matugen-theming-design.md` (status line)

- [ ] **Step 1: CLAUDE.md**

- Intro: `Personal NixOS flake: niri + DankMaterialShell, every colour taken from the wallpaper by DMS's matugen.`
- `## Where a file goes`, the `_lib` bullet: replace `Cross-cutting data read by several modules (themes/) lives at the repo root instead.` with nothing (the only such data is gone).
- `## Rules that bite`, the colour row becomes:
  `| Any colour | Never a hex value in Nix. The app module ships a matugen template (tokens like {{colors.primary.default.hex}}) and registers it in theming.matugen.templates; DMS renders it on every wallpaper change. Fonts come from fonts.fontconfig.defaultFonts |`
- Files-apps-also-write list: `VS Code's keybindings.json (and its settings.json, which stylix owns)` → `VS Code's keybindings.json and settings.json`; add `DMS's matugen outputs (ghostty/themes/dankcolors, niri/dms/colors.kdl, the Obsidian snippet, spicetify-dms/colors.css, …) — regenerated on every wallpaper change`.
- VS Code extensions paragraph: `so Claude Code's CLI and stylix can drop their own extensions in` → `so Claude Code's CLI and DMS (its dms-theme extension) can drop their own extensions in`.

- [ ] **Step 2: README.md**

`grep -n 'stylix\|catppuccin\|themes/' README.md` and rewrite each hit to describe wallpaper-driven theming: DMS + matugen, `theming.matugen.templates`, dharmx/walls. Keep `catppuccin-grub` mentions.

Screenshots in `assets/screenshots/` show the old palette; do not regenerate them, but add `(screenshots predate wallpaper theming)` next to where the README embeds them.

- [ ] **Step 3: Spec status**

Change `**Status:** approved design, not implemented` to `**Status:** implemented`.

- [ ] **Step 4: Check, commit**

```sh
just check
git add CLAUDE.md README.md docs/design/specs/2026-09-15-dms-matugen-theming-design.md
git commit -m "docs: describe wallpaper-driven theming in place of stylix

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01QaJ4aPtcZ2XQDY8iDdAWeH"
```

---

### Task 11: End-to-end verification

**Files:** none (fixes found here go into small follow-up commits)

- [ ] **Step 1: Static gates**

```sh
just fmt && git diff --exit-code
just check
nix shell nixpkgs#statix nixpkgs#deadnix --command sh -c 'statix check .; deadnix modules/ hosts/ flake/ flake.nix'
just drybuild
just build && just diff
```
Expected: clean, and the diff matches Task 7 Step 8. Paste the `just diff` summary to the user.

- [ ] **Step 2: Ask before switching**

Ask the user: "Everything builds. Switch omnibook to the `dms-mutagen` build now (`just rebuild`)?" Do not proceed without a yes.

- [ ] **Step 3: After switch — matugen wiring**

```sh
cat ~/.config/matugen/config.toml
journalctl --user -u dms -b --since "10 min ago" | grep -i 'matugen\|template' | tail -20
```
Expected: three user templates listed (obsidian, anki-recolor, spotify); no template errors.

- [ ] **Step 4: Pick a wallpaper, twice**

Ask the user to open DMS's wallpaper browser and pick an image from `nature/`, then one from a very different category (e.g. `outrun/`). After each pick, record modification times and a sample colour:

```sh
stat -c '%y %n' ~/.config/niri/dms/colors.kdl ~/.config/ghostty/themes/dankcolors \
  ~/.config/gtk-3.0/dank-colors.css ~/.config/qt6ct/colors/matugen.conf \
  ~/.config/zed/themes/dank-zed-theme.json ~/.config/nvim/colors/dms.lua \
  ~/.config/DankMaterialShell/zen.css ~/Documents/uni/.obsidian/snippets/sitolamix.css \
  ~/.local/state/sitolamix/anki-recolor.json ~/.config/spicetify-dms/colors.css
grep -m1 active-color ~/.config/niri/dms/colors.kdl
jq '.config.colors.CANVAS[2]' ~/.local/share/Anki2/addons21/688199788/meta.json
```
Expected: every file's mtime moves on each pick, and the sample colours differ between the two picks. Any file missing: check `ls ~/.config/gtk-3.0/gtk.css -l` (must not be a store symlink) and the DMS journal for that template.

- [ ] **Step 5: Visual check with the user**

Ask the user to open and confirm each shows wallpaper colours: ghostty (and starship/btop inside it), Nautilus, a Qt app (e.g. VLC or KDE Connect), zed, VS Code (theme `Dynamic Base16 DankShell (Dark)` active), neovim, zen, Helium, Vesktop, Obsidian, Anki (restart it), Spotify (restart it), the niri focus ring, the DMS lock screen. Collect a list of anything off.

- [ ] **Step 6: Fix and report**

For each problem the user reports, apply `superpowers:systematic-debugging`, fix in its own commit on this branch, and re-run Steps 1 and 4 for the affected app. Finish with a summary to the user: what works, what does not, and any follow-ups. Do not merge or push.
