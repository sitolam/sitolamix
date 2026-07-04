_:
{
  flake.modules.nixos.base =
    { pkgs, ... }:
    {
      fonts = {
        packages = with pkgs; [
          nerd-fonts.meslo-lg
          nerd-fonts.jetbrains-mono
          nerd-fonts.symbols-only
          dejavu_fonts
          noto-fonts
          noto-fonts-color-emoji
        ];

        fontconfig.defaultFonts = {
          serif = [ "DejaVu Serif" ];
          sansSerif = [ "DejaVu Sans" ];
          monospace = [ "MesloLGS Nerd Font Mono" ];
          emoji = [ "Noto Color Emoji" ];
        };
      };
    };
}
