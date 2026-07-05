{ }:
{
  # base16 scheme name under ${pkgs.base16-schemes}/share/themes/<name>.yaml
  themeName = "catppuccin-mocha";
  polarity = "dark";

  wallpaper = ../assets/wallpaper.jpg;

  # stylix.override (base16 slot tweaks), or null for none.
  override = null;

  # DankMaterialShell M3 tokens -> base16 slot names (resolved to hex from the
  # active stylix scheme in modules/desktop/dms.nix). Set to null to fall back to
  # stylix's own auto mapping. That mapping leads with base0D (blue) + surface0
  # containers, which reads Nord-ish; lead with mauve (base0E) and keep the bar
  # (surfaceContainer) on the darkest base slot instead.
  dms = {
    primary = "base0E"; # mauve
    primaryText = "base00"; # base
    primaryContainer = "base07"; # lavender
    secondary = "base0D"; # blue
    surface = "base00"; # base
    surfaceText = "base05"; # text
    surfaceVariant = "base01"; # surface0
    surfaceVariantText = "base04"; # subtext0
    surfaceTint = "base0E"; # mauve
    background = "base00"; # base (darkest slot available)
    backgroundText = "base05"; # text
    outline = "base03"; # overlay0
    surfaceContainer = "base00"; # bar background — keep it dark, not surface0
    surfaceContainerHigh = "base01"; # surface0
    surfaceContainerHighest = "base02"; # surface1
    error = "base08"; # red
    warning = "base0A"; # yellow
    info = "base0C"; # teal
  };
}
