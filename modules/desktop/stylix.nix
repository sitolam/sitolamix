{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.theming.stylix;
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  options.theming.stylix.enable = lib.mkEnableOption "stylix system-wide theming (catppuccin-mocha)";

  config = lib.mkIf cfg.enable {
    stylix = {
      enable = true;

      image = ../../assets/wallpaper.jpg;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
      polarity = "dark";

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
        terminal = 0.9;
        applications = 0.9;
        desktop = 0.95;
        popups = 0.95;
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
