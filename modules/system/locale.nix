{
  time.timeZone = "Europe/Brussels";
  i18n.defaultLocale = "en_US.UTF-8";

  # `us-intl` is an xkb layout name, not a valid kbd console keymap — using it
  # directly makes systemd-vconsole-setup fail ("loadkeys: us-intl: No such
  # file"). useXkbConfig derives the console map from the xkb layout below
  # instead. For a plain dead-key map, use `console.keyMap = "us-acentos"`.
  console.useXkbConfig = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "intl";
    options = "compose:ralt";
  };
}
