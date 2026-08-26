{ pkgs, ... }:
{
  fonts = {
    packages = with pkgs; [
      # UI / terminal (stylix picks its faces from these, see ../theming/stylix.nix)
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

      # Windows fonts. Documents from the outside world ask for these by name;
      # without them fontconfig substitutes something with different metrics and
      # the layout drifts (school .docx/.pptx are the usual offenders).
      #   corefonts   -> Arial, Times New Roman, Courier New, Georgia, Verdana,
      #                  Trebuchet MS, Comic Sans MS, Impact, Andale Mono, Webdings
      #   vista-fonts -> the ClearType set: Calibri (Office's default since 2007),
      #                  Cambria, Candara, Consolas, Constantia, Corbel
      # Both are unfree-but-redistributable and allowUnfree is on (../system/nix.nix);
      # vista-fonts is not in the binary cache, it extracts the fonts out of
      # Microsoft's PowerPoint Viewer installer at build time.
      # Segoe UI (the Windows shell font) has no redistributable source, so it is
      # not packaged anywhere — nothing to add here for it.
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
