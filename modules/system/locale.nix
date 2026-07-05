{
  time.timeZone = "Europe/Brussels";
  i18n.defaultLocale = "en_US.UTF-8";

  # US-International on the TTY, derived from the same xkb layout niri uses
  # (`us-intl` is an xkb layout name, not a valid kbd console keymap — using it
  # directly makes systemd-vconsole-setup fail with "loadkeys: us-intl: No such
  # file"). For a plain dead-key console map instead, use `console.keyMap = "us-acentos"`.
  console.useXkbConfig = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "intl";
    options = "compose:ralt";
  };
}
