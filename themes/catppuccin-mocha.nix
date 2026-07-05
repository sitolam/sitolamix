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
    surface = "#313244";
    surfaceText = "#cdd6f4";
    surfaceVariant = "#45475a";
    surfaceVariantText = "#a6adc8";
    surfaceTint = "#cba6f7";
    background = "#1e1e2e";
    backgroundText = "#cdd6f4";
    outline = "#6c7086";
    surfaceContainer = "#313244";
    surfaceContainerHigh = "#45475a";
    surfaceContainerHighest = "#6c7086";
    error = "#f38ba8"; # red
    warning = "#f9e2af"; # yellow
    info = "#94e2d5"; # teal
  };
}
