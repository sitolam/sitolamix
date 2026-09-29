{ pkgs, ... }:
{
  fonts = {
    packages = with pkgs; [
      # UI / terminal (fontconfig defaults below; DMS, Obsidian and the GTK font read them)
      nerd-fonts.meslo-lg
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      dejavu_fonts

      # Broad Unicode coverage, so foreign scripts render as glyphs, not tofu.
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      unifont

      # Windows fonts (Arial/Times/Calibri/etc, corefonts + vista-fonts): school
      # .docx/.pptx ask for these by name, and without them fontconfig
      # substitutes something with different metrics and the layout drifts.
      # Both unfree-but-redistributable, allowUnfree is on (./nix.nix).
      # Segoe UI has no redistributable source, so it isn't packaged anywhere.
      corefonts
      vista-fonts
      cascadia-code

      # Metric-compatible clones of Arial/Times/Courier. Redundant next to
      # corefonts for exact matches, but LibreOffice reaches for them when a
      # document names an MS font we do *not* ship, keeping the metrics right.
      liberation_ttf
    ];

    fontconfig.defaultFonts = {
      serif = [ "DejaVu Serif" ];
      sansSerif = [ "DejaVu Sans" ];
      monospace = [ "MesloLGS Nerd Font Mono" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
