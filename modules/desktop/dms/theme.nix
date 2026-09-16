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
      # frosted-glass blur behind DMS surfaces (bar, popouts, modals).
      blurEnabled = true;
      # "Foreground Layers" under Theme > Surface Styling: off, so cards
      # nested inside popouts get no extra tinted surface of their own.
      blurForegroundLayers = false;
      # Same toggle under Theme > Floating Windows (Settings, Notepad, polkit
      # prompts). While "Sync with Global Settings" is on, DMS uses the global
      # value above; set it explicitly too so it stays off if sync is turned off.
      floatingWindowForegroundLayers = false;
      # blur the wallpaper inside the overview. Two cooperating pieces:
      #  - blurWallpaperOnOverview: blurs the live wallpaper in the workspace
      #    tiles (internal MultiEffect, gated on inOverview).
      #  - blurredWallpaperLayer: draws a blurred wallpaper duplicate on the
      #    dms:blurwallpaper background layer, which the niri layer-rule (see
      #    niri.nix) pins into the overview backdrop (place-within-backdrop).
      blurWallpaperOnOverview = true;
      blurredWallpaperLayer = true;
      # blur only shows through transparent pixels (DMS: readableSurface =
      # withAlpha(surfaceContainer, popupTransparency) — so this is the
      # surface *alpha*, 1.0 = fully opaque). 0.3 is glassy; raise toward 0.5
      # for more solid/readable.
      popupTransparency = 0.3;
      dockTransparency = 0.3;
    };
  };
}
