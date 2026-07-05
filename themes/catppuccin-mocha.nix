{ }:
{
  # base16 scheme name under ${pkgs.base16-schemes}/share/themes/<name>.yaml
  themeName = "catppuccin-mocha";
  polarity = "dark";

  wallpaper = ../assets/wallpaper.jpg;

  # stylix.override (base16 slot tweaks), or null for none.
  override = null;

  # DankMaterialShell palette (Material-3 tokens). Set to null to fall back to
  # stylix's auto-generated base16->M3 mapping. That mapping leads with base0D
  # (blue), which makes mocha read Nord-ish — so lead with mauve here instead.
  dms = {
    name = "Catppuccin Mocha";
    primary = "#cba6f7"; # mauve
    primaryText = "#1e1e2e";
    primaryContainer = "#b4befe"; # lavender
    secondary = "#89b4fa"; # blue
    # proper catppuccin dark hierarchy: crust < mantle < base < surface0/1.
    # DMS paints the bar with surfaceContainer, so keep that dark (mantle) —
    # surface0 (#313244) is a cool blue-grey that reads Nord-ish.
    surface = "#1e1e2e"; # base
    surfaceText = "#cdd6f4"; # text
    surfaceVariant = "#313244"; # surface0
    surfaceVariantText = "#a6adc8"; # subtext0
    surfaceTint = "#cba6f7"; # mauve
    background = "#11111b"; # crust
    backgroundText = "#cdd6f4"; # text
    outline = "#6c7086"; # overlay0
    surfaceContainer = "#181825"; # mantle (bar background)
    surfaceContainerHigh = "#313244"; # surface0
    surfaceContainerHighest = "#45475a"; # surface1
    error = "#f38ba8"; # red
    warning = "#f9e2af"; # yellow
    info = "#94e2d5"; # teal
  };
}
