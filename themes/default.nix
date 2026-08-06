# Theme registry. Each entry is a base16 scheme plus a polarity; consumed by
# modules/desktop/stylix.nix (which picks the scheme) and
# modules/desktop/dms/theme.nix (which resolves the `dms` slot map into hex),
# selected via the `theming.stylix.theme` option, and turned into one NixOS
# specialisation per theme by modules/desktop/theme-switch.nix.
#
# Lives outside ./modules so import-tree doesn't try to load this data file as a
# NixOS module.
#
# Themes deliberately carry no wallpaper: the wallpaper is runtime state owned by
# DMS (see modules/desktop/dms/default.nix), not a property of the colour scheme.
{ lib }:
let
  # DankMaterialShell M3 tokens -> base16 *slot names*. Slots, not colours, so
  # this is scheme-independent and every theme shares it — it gets resolved
  # against the active stylix scheme in modules/desktop/dms/theme.nix.
  #
  # stylix's own auto mapping leads with base0D (blue) + surface0 containers,
  # which reads Nord-ish whatever the scheme is. Lead with base0E (the "purple"
  # slot) instead, and keep the bar (surfaceContainer) on the darkest slot.
  defaultDms = {
    primary = "base0E";
    primaryText = "base00";
    primaryContainer = "base07";
    secondary = "base0D";
    surface = "base00";
    surfaceText = "base05";
    surfaceVariant = "base01";
    surfaceVariantText = "base04";
    surfaceTint = "base0E";
    background = "base00";
    backgroundText = "base05";
    outline = "base03";
    surfaceContainer = "base00"; # bar background — dark, not surface0
    surfaceContainerHigh = "base01";
    surfaceContainerHighest = "base02";
    error = "base08"; # red
    warning = "base0A"; # yellow
    info = "base0C"; # cyan/teal
  };

  # Everything but themeName has a sensible default, so adding a theme is one
  # line. `dms = null` falls back to stylix's own auto mapping.
  mkTheme =
    {
      themeName,
      polarity ? "dark",
      override ? null, # stylix.override — base16 slot tweaks
      dms ? defaultDms,
    }:
    {
      inherit
        themeName
        polarity
        override
        dms
        ;
    };

  # Six schemes with genuinely distinct personalities rather than six shades of
  # one idea. All ship in pkgs.base16-schemes (tinted-theming, 303 schemes).
  themes = lib.mapAttrs (_name: mkTheme) {
    catppuccin-mocha = {
      themeName = "catppuccin-mocha";
    };
    nord = {
      themeName = "nord";
    };
    gruvbox-dark-hard = {
      themeName = "gruvbox-dark-hard";
    };
    tokyo-night-storm = {
      themeName = "tokyo-night-storm";
    };
    rose-pine = {
      themeName = "rose-pine";
    };
    everforest-dark-medium = {
      themeName = "everforest-dark-medium";
    };
  };
in
{
  inherit themes defaultDms mkTheme;

  names = lib.attrNames themes;

  get =
    name:
    themes.${name}
      or (throw "Unknown theme: ${name}. Available: ${lib.concatStringsSep ", " (lib.attrNames themes)}");
}
