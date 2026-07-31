{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.theming.stylix;
  themes = import ../../themes { inherit lib; };
  theme = themes.get cfg.theme;
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  options.theming.stylix = {
    enable = lib.mkEnableOption "stylix system-wide theming";
    theme = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin-mocha";
      description = "Theme to use from ./themes (by attr name).";
    };
  };

  config = lib.mkIf cfg.enable {
    # stylix drives the cursor via home.pointerCursor; newer HM wants the
    # generation flag set explicitly instead of inferred from the theme name.
    home.extraOptions.home.pointerCursor.enable = true;

    stylix = {
      enable = true;

      image = theme.wallpaper;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${theme.themeName}.yaml";
      polarity = theme.polarity;
      override = lib.mkIf (theme.override != null) theme.override;

      cursor = {
        name = "Bibata-Modern-Classic";
        package = pkgs.bibata-cursors;
        size = 7;
      };

      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.meslo-lg;
          name = "MesloLGS Nerd Font Mono";
        };
        sansSerif = {
          package = pkgs.dejavu_fonts;
          name = "DejaVu Sans";
        };
        serif = {
          package = pkgs.dejavu_fonts;
          name = "DejaVu Serif";
        };

        sizes = {
          applications = 12;
          terminal = 15;
          desktop = 10;
          popups = 10;
        };
      };

      opacity = {
        terminal = 0.8;
        applications = 0.8;
        desktop = 0.8;
        popups = 0.8;
      };

      icons = {
        enable = true;
        dark = "WhiteSur";
        package = pkgs.whitesur-icon-theme;
      };

      targets = {
        # bootloader handled by catppuccin-grub package directly
        grub.enable = false;
        plymouth.enable = false;
        console.enable = false;
        gnome.enable = true;
        gtk.enable = true;
      };
    };
  };
}
