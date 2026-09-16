# Wallpaper-driven theming: stylix out, DMS matugen in

**Date:** 2026-09-15
**Status:** implemented
**Branch:** `dms-mutagen`

## Problem

Colour in this repo is a fixed catppuccin-mocha palette. stylix turns
`themes/catppuccin-mocha.nix` into GTK, Qt, terminal and editor themes, and the
same file carries hand-written palette tables for DMS (`dms`), Obsidian
(`obsidian`) and Anki's ReColor (`recolor`). The wallpapers are
`orangci/walls-catppuccin-mocha`, picked to match that palette.

DankMaterialShell can do the opposite: derive a Material 3 scheme from the
current wallpaper with matugen and write app themes from it. That is switched
off today (`DMS_DISABLE_MATUGEN=1`, `enableDynamicTheming = false`) so it does
not fight stylix.

Goal: every themed surface follows the wallpaper. Picking a new wallpaper in
DMS re-colours the shell and the applications without a rebuild.

## Decisions taken

- stylix is removed entirely, not kept for fonts or cursors.
- `themes/` is removed. No colour is written as hex in Nix after this change.
- Wallpapers come from `github:dharmx/walls`, the whole repository, as a
  `flake = false` input.
- Coverage is everything: applications with no built-in DMS template get a
  matugen user template in this repo.
- Always dark. No light-mode variants are written.
- Scheme is `scheme-tonal-spot`, declared in Nix. `settings.json` stays a
  Home Manager store symlink, so a scheme picked in the DMS UI lasts only until
  DMS restarts; changing it for good is a Nix edit.
- GRUB keeps `catppuccin-grub`. It renders before any wallpaper is known.
- Spotify follows the wallpaper too (see Spotify below).

## Architecture

### Removed

- `stylix` flake input and `modules/theming/stylix.nix`.
- `themes/default.nix`, `themes/catppuccin-mocha.nix`.
- In the DMS module: `DMS_DISABLE_MATUGEN`, `enableDynamicTheming = false`,
  `customThemeFile`, `gtkThemingEnabled = false`, `qtThemingEnabled = false`,
  and the `mkForce` on the transparency values (stylix no longer sets them).
- Every `config.lib.stylix.*` and `config.stylix.*` reference
  (niri appearance, spotify, obsidian, anki, omnibook host).

### `theming.matugen` — new module

`modules/theming/matugen.nix`, enabled by `suites.desktop` in place of
`theming.stylix`.

It declares:

```nix
theming.matugen.templates.<name> = {
  input = <path>;          # template file, next to the app module that owns it
  output = <string>;       # absolute path, or ~-relative
  postHook = <null or str>;
};
```

and renders them into `~/.config/matugen/config.toml` under `[templates]`.
DMS reads that file's `[templates]` section and appends it to its own merged
matugen config when `runUserMatugenTemplates = true`
(`core/internal/matugen/matugen.go`, `buildMergedConfig`).

This keeps the one-feature-one-file rule: the Obsidian template lives in
`modules/apps/obsidian/`, the ReColor template in `modules/apps/anki/`, and so
on. `theming.matugen` only collects them. An app module that adds a template
file becomes a directory if it is not one already.

The same module takes over the non-colour work stylix did:

- cursor: `home.pointerCursor` with `bibata-cursors` / `Bibata-Modern-Classic`,
  exposed as `theming.matugen.cursorSize` (default 7; omnibook sets 16 with
  its existing comment).
- icons: `gtk.iconTheme` = WhiteSur.
- GTK base theme: `adw-gtk3`, which DMS's gtk template recolours.
- Qt: `qt6ct` and `qt5ct` installed, `QT_QPA_PLATFORMTHEME=qt6ct`, so DMS's
  qtct and kcolorscheme templates apply. kvantum goes away.
- fonts: `modules/system/fonts.nix` already sets fontconfig defaults (Meslo,
  DejaVu). Applications that took their font from stylix get it set in their
  own module (ghostty, zed, VS Code, Obsidian, DMS itself).

### DMS settings

In `modules/desktop/dms/theme.nix`:

```nix
currentThemeName = "dynamic";
matugenScheme = "scheme-tonal-spot";
runUserMatugenTemplates = true;
gtkThemingEnabled = true;
qtThemingEnabled = true;
```

plus whichever setting forces dark mode, and `enableDynamicTheming = true` in
`default.nix`. Blur and transparency settings stay as they are.

### Wallpapers

`wallpapers` input becomes `github:dharmx/walls`, `flake = false`, still linked
to `~/Pictures/Wallpapers` by `modules/desktop/wallpapers.nix`.

dharmx/walls is split into category folders. DMS's cycling service cycles the
*directory of the current wallpaper*, so cycling stays inside one category.
The seeded default is an image in `nature/`; the filename guard in
`wallpapers.nix` is adapted to look inside that folder.

The repository has no licence file. It is fetched, not vendored, so nothing is
copied into this repo; the flake input comment records the missing licence.

GitHub reports 3.8 GB including history; the tarball is smaller but still
large. Both hosts fetch it.

## Per-application theming

| Application | Mechanism |
|---|---|
| DMS shell, lock screen | built in (`currentThemeName = "dynamic"`) |
| greeter | unchanged: greetd copies `dms-colors.json` at start |
| niri | DMS `niri` template writes `~/.config/niri/dms/colors.kdl`; add `"colors"` to `dank-material-shell.niri.includes.filesToInclude`; remove the stylix focus-ring and overview backdrop colours from `niri/appearance.nix` |
| GTK apps (Nautilus, gparted, Helium dialogs) | DMS `gtk` template over `adw-gtk3` |
| Qt apps (Anki's window, KDE Connect) | DMS `qt6ct`/`qt5ct` and `kcolorscheme` templates |
| ghostty | DMS writes `ghostty/themes/dankcolors`; set `theme = "dankcolors"` and the font directly |
| starship, tmux, yazi, btop, fish, cliamp, nitch | take the terminal's ANSI palette, which DMS's `dank16` fills; starship loses `palette = "base16"`, btop gets `color_theme = "TTY"` |
| neovim | `matugenTemplateNeovim = true`; `colorscheme dms` in init |
| zed | DMS writes `zed/themes/dank-zed-theme.json`; set `theme` and fonts in `userSettings` |
| VS Code | DMS only *renders* theme JSON into an already-installed `danklinux.dms-theme-*` extension (it globs for one and silently no-ops without a match) — it never installs the extension itself; `vscode.nix` deploys DMS's VSIX build tree as a writable copy under `~/.vscode/extensions` so matugen has somewhere to write, and sets `workbench.colorTheme` and the fonts stylix used to own; CLAUDE.md's note that stylix owns `settings.json` is updated |
| zen | DMS `zenbrowser` template writes `DankMaterialShell/zen.css`; linked as `chrome/userChrome.css` in the zen profile with `toolkit.legacyUserProfileCustomizations.stylesheets` enabled |
| Helium | no template exists; Chromium's GTK theme mode, set through Helium's prefs/policies, takes colours from the GTK theme |
| Obsidian | user template writes the vault CSS snippet that `obsidian/default.nix` currently generates at activation |
| Anki ReColor | user template renders a colours JSON; `postHook` merges it into ReColor's `meta.json` with `jq`; takes effect on Anki restart |
| Spotify | see below |

### Obsidian and Anki slot mapping

Their tables map named slots to catppuccin swatch names. They become matugen
tokens. Structural slots map to Material 3 roles; slots that need several
distinct hues (headings, callouts, flags, card states) use `dank16`, the
harmonised 16-colour palette DMS derives from the scheme.

Obsidian:

| Slot | Token |
|---|---|
| accent | `primary` |
| background | `surface` |
| backgroundAlt, sidebar | `surface_container_low` |
| sidebarAlt | `surface_container_lowest` |
| border, hover | `surface_container_high` |
| active, selection | `surface_container_highest` |
| text | `on_surface` |
| textMuted | `on_surface_variant` |
| textFaint | `outline` |
| textOnAccent | `on_primary` |
| link | `secondary` |
| linkHover | `tertiary` |
| linkUnresolved, error | `error` |
| highlight | `dank16.color3` (yellow) |
| code | `dank16.color9` |
| codeBackground | `surface_container_low` |
| success | `dank16.color2` |
| tag | `dank16.color6` |
| headings h1–h6 | `primary`, `secondary`, `tertiary`, `dank16.color6`, `dank16.color2`, `on_surface_variant` |
| callouts | same hue families as today, each mapped to the nearest `dank16` colour; proof/solution/remark stay on `outline`/`on_surface_variant` |

Anki ReColor: canvas slots → `surface`/`surface_container_*`; foreground →
`on_surface`/`on_surface_variant`/`outline`; borders → `outline_variant`/
`outline`; buttons → `surface_container_high(est)`, primary button →
`primary`/`primary_container`; selection and highlight → `secondary_container`/
`on_secondary_container`; flags and card states → `dank16` hues matching their
current meaning (learn red, review green, new blue, marked yellow). The custom
hex tweaks in `recolor` disappear. `recolor-schema.json` still supplies the
light values and labels.

### Spotify

spicetify-nix compiles the colour scheme into the Spotify build in the store,
so a runtime change cannot reach it. The spiced build loads colours from a
separate `Apps/xpui/colors.css`, referenced by `index.html` alongside
`user.css`.

Approach: keep spicetify-nix, so the theme, extensions and custom apps stay
pinned by `flake.lock`. Post-process the spiced Spotify derivation so
`Apps/xpui/colors.css` is a symlink to `/home/otis/.config/spicetify-dms/colors.css`.
A matugen user template in `modules/apps/spotify/` writes that file as
`--spice-*` and `--spice-rgb-*` CSS variables. Spotify reads it on start.

Risk: this depends on Spotify's embedded Chromium following a symlink out of
the store. The first implementation task verifies it before anything else is
built on it. If it does not work, the fallback is mutable `spicetify-cli`
against a writable copy of Spotify, with the template's `postHook` running
`spicetify apply`; that loses flake-pinned extensions and needs its own
approval.

## Documentation changes

- `CLAUDE.md`: the "any colour, font or wallpaper" rule becomes "colours come
  from matugen templates owned by the app module; never a hex value in Nix".
  The `themes/` and `_lib` notes, the stylix `settings.json` note and the
  `theming.<name>` examples are updated.
- `README.md` and `flake.nix`'s description: stylix and catppuccin-mocha out.
- Comments that cite stylix as the reason for something (niri polkit and
  kvantum, anki's `QT_PLUGIN_PATH`, ghostty fonts, `nixpkgs-stable.nix`) are
  rewritten or removed.

## Verification

1. `just fmt`, `just check` (both hosts), statix and deadnix clean.
2. `just build && just diff`: stylix, kvantum and base16 closures gone;
   adw-gtk3, qt6ct, qt5ct, walls present.
3. Before switching, ask. After switching on omnibook:
   - DMS starts with a dynamic scheme; `~/.config/matugen/config.toml` exists.
   - Pick two very different wallpapers in DMS. After each, check that
     `niri/dms/colors.kdl`, `ghostty/themes/dankcolors`, the Obsidian snippet,
     ReColor's `meta.json` and `spicetify-dms/colors.css` changed.
   - Open ghostty, Nautilus, a Qt app, zed, VS Code, zen, Helium, Obsidian,
     Anki and Spotify and confirm each shows the new colours.
   - `journalctl --user -u dms` shows no matugen template errors.

## Out of scope

- Light mode.
- Making `settings.json` mutable or merging runtime changes into it.
- Theming GRUB, the TTY console or Plymouth from the wallpaper.
