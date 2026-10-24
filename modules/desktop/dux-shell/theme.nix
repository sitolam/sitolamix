{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.dux-shell.enable {
    home.extraOptions.programs.dank-material-shell.settings = {
      # Colours come from the wallpaper. DMS runs matugen on every wallpaper
      # change and renders its built-in templates plus the user templates
      # modules collect through theming.matugen.templates.
      currentThemeName = "dynamic";
      # Declared here since settings.json is a store symlink — a scheme picked
      # in the UI lasts only until DMS restarts. fidelity tracks the
      # wallpaper's own colours most literally; tonal-spot (the alternative)
      # washes a photo's palette down to one hue.
      matugenScheme = "scheme-fidelity";
      runUserMatugenTemplates = true;

      # neovim's template is off by default in DMS; modules/apps/neovim.nix
      # ships the base46 fork it needs.
      matugenTemplateNeovim = true;

      fontFamily = lib.head config.fonts.fontconfig.defaultFonts.sansSerif;
      monoFontFamily = lib.head config.fonts.fontconfig.defaultFonts.monospace;

      # blur (niri 26.04 ext-background-effect): frosted glass behind DMS
      # surfaces (bar, popouts, modals).
      blurEnabled = true;
      # Thin border around blurred surfaces; 2.0 split it out of blurEnabled.
      # Seeded marks it as already decided so DMS doesn't re-derive it.
      blurBorderEnabled = true;
      blurBorderSeeded = true;
      # "Foreground layers" (Theme > Surfaces): cards nested inside popouts get
      # a faint tinted surface of their own, at 25% alpha.
      blurForegroundLayers = true;
      foregroundLayerTransparency = 0.25;
      # Same toggle for floating windows (Settings, Notepad, polkit prompts);
      # set explicitly so it stays off even if "Sync with Global Settings" is
      # turned off.
      floatingWindowForegroundLayers = false;
      # Blur the wallpaper in the overview: blurWallpaperOnOverview blurs the
      # live tiles, blurredWallpaperLayer draws a duplicate on the
      # dms:blurwallpaper layer that the niri.nix layer-rule pins into the
      # overview backdrop.
      blurWallpaperOnOverview = true;
      blurredWallpaperLayer = true;
      # Surface alpha where blur shows through (1.0 = opaque). 0.3 is glassy;
      # raise toward 0.5 for more solid/readable.
      popupTransparency = 0.3;
    };
  };
}
