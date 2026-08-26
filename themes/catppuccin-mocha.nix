_:
let
  # Catppuccin Mocha's official named palette (catppuccin.com/palette) --
  # the source of truth for anything below that wants a swatch by name
  # instead of repeating raw hex (see `recolor`).
  palette = {
    rosewater = "#f5e0dc";
    flamingo = "#f2cdcd";
    pink = "#f5c2e7";
    mauve = "#cba6f7";
    red = "#f38ba8";
    maroon = "#eba0ac";
    peach = "#fab387";
    yellow = "#f9e2af";
    green = "#a6e3a1";
    teal = "#94e2d5";
    sky = "#89dceb";
    sapphire = "#74c7ec";
    blue = "#89b4fa";
    lavender = "#b4befe";
    text = "#cdd6f4";
    subtext1 = "#bac2de";
    subtext0 = "#a6adc8";
    overlay2 = "#9399b2";
    overlay1 = "#7f849c";
    overlay0 = "#6c7086";
    surface2 = "#585b70";
    surface1 = "#45475a";
    surface0 = "#313244";
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";
  };
in
{
  # base16 scheme name under ${pkgs.base16-schemes}/share/themes/<name>.yaml
  themeName = "catppuccin-mocha";
  polarity = "dark";

  inherit palette;

  # stylix.override (base16 slot tweaks), or null for none.
  override = null;

  # DankMaterialShell M3 tokens -> base16 slot names (resolved to hex from the
  # active stylix scheme in modules/desktop/dms/theme.nix). Set to null to fall back to
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

  # ReColor (Anki addon, anki-addons/fetched) dark-mode swatch per color key --
  # either a `palette` name above or a literal hex for one-off custom tweaks.
  # Light-mode values, labels and CSS var names come from ReColor's own
  # shipped config.json (see anki-addons/recolor-schema.json); only the dark
  # slot is theme-driven. Resolved and written to ReColor's meta.json on every
  # activation in anki-addons/default.nix, so changing the active theme
  # re-colors Anki too.
  recolor = {
    ACCENT_CARD = "blue";
    ACCENT_DANGER = "red";
    ACCENT_NOTE = "green";
    BORDER = "surface1";
    BORDER_FOCUS = "rosewater";
    BORDER_STRONG = "surface2";
    BORDER_SUBTLE = "surface0";
    BUTTON_BG = "surface0";
    BUTTON_DISABLED = "surface0";
    BUTTON_HOVER = "surface1";
    BUTTON_HOVER_BORDER = "surface2";
    BUTTON_PRIMARY_BG = "#2f67e1"; # custom, not a stock palette swatch
    BUTTON_PRIMARY_DISABLED = "#4484ed"; # custom, not a stock palette swatch
    BUTTON_PRIMARY_GRADIENT_END = "#2544a8"; # custom, not a stock palette swatch
    BUTTON_PRIMARY_GRADIENT_START = "#2f67e1"; # custom, not a stock palette swatch
    CANVAS = "base";
    CANVAS_CODE = "mantle";
    CANVAS_ELEVATED = "mantle";
    CANVAS_GLASS = "#18182566"; # custom, not a stock palette swatch (mantle + alpha)
    CANVAS_INSET = "crust";
    CANVAS_OVERLAY = "mantle";
    FG = "text";
    FG_DISABLED = "#a6adc6"; # custom, not a stock palette swatch
    FG_FAINT = "overlay2";
    FG_LINK = "rosewater";
    FG_SUBTLE = "subtext1";
    FLAG_1 = "red";
    FLAG_2 = "peach";
    FLAG_3 = "green";
    FLAG_4 = "blue";
    FLAG_5 = "mauve";
    FLAG_6 = "sky";
    FLAG_7 = "#c9cbff"; # custom, not a stock palette swatch
    HIGHLIGHT_BG = "surface0";
    HIGHLIGHT_FG = "rosewater";
    SCROLLBAR_BG = "base";
    SCROLLBAR_BG_ACTIVE = "surface0";
    SCROLLBAR_BG_HOVER = "base";
    SELECTED_BG = "surface0";
    SELECTED_FG = "rosewater";
    SHADOW = "base";
    SHADOW_FOCUS = "peach";
    SHADOW_INSET = "crust";
    SHADOW_SUBTLE = "mantle";
    STATE_BURIED = "overlay1";
    STATE_LEARN = "red";
    STATE_MARKED = "#FAE3B0"; # custom, not a stock palette swatch
    STATE_NEW = "#96cdfb"; # custom, not a stock palette swatch
    STATE_REVIEW = "green";
    STATE_SUSPENDED = "subtext0";
  };
}
