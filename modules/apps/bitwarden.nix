{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.apps.bitwarden;
in
{
  options.apps.bitwarden.enable = lib.mkEnableOption "Bitwarden desktop app (biometric unlock for the Helium extension)";

  config = lib.mkIf cfg.enable {
    # The Helium extension (modules/apps/helium/default.nix) can only unlock
    # via "system authentication" if this desktop app is installed and
    # running: it is what speaks native messaging to the extension and owns
    # the polkit prompt. See
    # https://bitwarden.com/help/biometrics/#tab-linux-2vCWb5iFg4OqKS0B2xXpqW
    environment.systemPackages = [ pkgs.bitwarden-desktop ];

    # bitwarden-desktop ships its own polkit action
    # (com.bitwarden.Bitwarden.unlock) under share/polkit-1/actions — NixOS's
    # polkit service already scans every systemPackage's share/polkit-1, so
    # nothing else is needed here. This machine has no fingerprint reader, so
    # "biometric" unlock resolves to auth_self: a polkit password/PIN prompt
    # via polkit_gnome (modules/system/security.nix, wired up in
    # modules/desktop/niri/default.nix), not an actual fingerprint.
    #
    # What nix can't do: the app writes its own native-messaging manifest
    # (~/.config/net.imput.helium/NativeMessagingHosts/com.8bit.bitwarden.json)
    # only when you flip "Unlock with system authentication" under Settings >
    # Security inside the running app — same one-time-by-hand pattern as the
    # uBlock Origin toggle in modules/apps/helium/default.nix. Log into the
    # vault there once, then the extension's "Unlock with biometrics" toggle
    # lights up.
  };
}
