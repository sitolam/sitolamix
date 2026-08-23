{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.services.winapps;

  winappsPkg = inputs.winapps.packages.${pkgs.stdenv.hostPlatform.system}.winapps;

  appIds = cfg.apps;

  # WinApps ships one directory per supported application, each with an `info`
  # file (a shell fragment defining NAME, FULL_NAME, WIN_EXECUTABLE, CATEGORIES,
  # MIME_TYPES). Upstream's setup.sh reads those at *install* time, probing a
  # running VM and writing into ~/.local behind home-manager's back. Reading
  # them at *build* time instead means the launchers exist after a rebuild
  # whether or not the VM has ever booted, and a bad app id fails the build
  # rather than producing a launcher that silently does nothing.
  desktopEntries = pkgs.runCommand "winapps-desktop-entries" { } ''
    mkdir -p "$out"

    for id in ${lib.escapeShellArgs appIds}; do
      info="${winappsPkg}/src/apps/$id/info"
      if [ ! -f "$info" ]; then
        echo "winapps: no such application id '$id'" >&2
        echo "available:" >&2
        ls "${winappsPkg}/src/apps" >&2
        exit 1
      fi

      NAME=""; FULL_NAME=""; CATEGORIES=""; MIME_TYPES=""
      # shellcheck disable=SC1090
      . "$info"

      {
        echo "[Desktop Entry]"
        echo "Type=Application"
        echo "Name=$NAME"
        echo "Comment=$FULL_NAME"
        echo "Exec=${winappsPkg}/bin/winapps $id %f"
        echo "Icon=${winappsPkg}/src/apps/$id/icon.svg"
        echo "Terminal=false"
        # FreeRDP sets the RemoteApp window's class from the Windows-side
        # application name, so this is what lets niri match the window to this
        # entry (and what makes the taskbar icon correct).
        echo "StartupWMClass=$FULL_NAME"
        # winapps only ever reads its second argument, so %f (one file) rather
        # than %F (a list) — opening several files at once would silently drop
        # all but the first.
        echo "Categories=''${CATEGORIES:-WinApps};"
        echo "MimeType=''${MIME_TYPES:-}"
      } > "$out/$id.desktop"
    done

    # The full remote desktop, for the rare thing with no launcher of its own.
    {
      echo "[Desktop Entry]"
      echo "Type=Application"
      echo "Name=Windows"
      echo "Comment=Full Windows desktop over RDP"
      echo "Exec=${winappsPkg}/bin/winapps windows"
      echo "Icon=${winappsPkg}/src/install/windows.svg"
      echo "Terminal=false"
      echo "StartupWMClass=Microsoft Windows"
      echo "Categories=System;WinApps;"
    } > "$out/windows.desktop"
  '';

  # winapps.conf is a plain shell file the launcher sources, and it has to carry
  # the RDP password — so it cannot be a store file. Written at activation
  # instead, as root (which can read the sops secret regardless of owner), then
  # handed to the user 0600.
  #
  # This runs as a *system* activation script rather than a home-manager one so
  # it can be ordered after sops-nix's `setupSecrets`; home-manager activation
  # has no such ordering guarantee, and on a fresh boot would read a secret that
  # is not decrypted yet.
  writeConf = pkgs.writeShellScript "winapps-write-conf" ''
    set -eu
    # NixOS activation runs under umask 0022, which is inherited here. Without
    # this, `cat >` below would create winapps.conf mode 0644 (world-readable,
    # root-owned) for the brief window before the explicit chmod/chown land —
    # and if chown fails, `set -eu` aborts and leaves that world-readable
    # plaintext-password file behind for good. Do not delete this as
    # "redundant" with the chmod calls below: it is what makes them race-free.
    umask 077
    secret=${config.sops.secrets.winapps_vm_env.path}
    dir=/home/otis/.config/winapps
    conf="$dir/winapps.conf"

    user=$(${pkgs.gnused}/bin/sed -n 's/^USERNAME=//p' "$secret")
    pass=$(${pkgs.gnused}/bin/sed -n 's/^PASSWORD=//p' "$secret")

    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    ${pkgs.coreutils}/bin/cat > "$conf" <<EOF
    RDP_USER="$user"
    RDP_PASS="$pass"
    RDP_DOMAIN=""
    RDP_IP="127.0.0.1"
    RDP_SCALE=100
    WAFLAVOR="manual"
    AUTOPAUSE="off"
    DEBUG="false"
    EOF

    ${pkgs.coreutils}/bin/chown otis:users "$dir" "$conf"
    ${pkgs.coreutils}/bin/chmod 0700 "$dir"
    ${pkgs.coreutils}/bin/chmod 0600 "$conf"
  '';
in
{
  config = lib.mkIf cfg.enable {
    system.activationScripts.winappsConf = {
      deps = [ "setupSecrets" ];
      text = "${writeConf}";
    };

    home.extraOptions = {
      home.packages = [ winappsPkg ];

      xdg.dataFile =
        lib.listToAttrs (
          map (
            id:
            lib.nameValuePair "applications/winapps-${id}.desktop" {
              source = "${desktopEntries}/${id}.desktop";
            }
          ) (appIds ++ [ "windows" ])
        )
        // {
          # Required, not decorative: `winapps <id>` looks for the app
          # definition here. The package keeps its copy under src/apps, which is
          # not on any path the launcher searches. See src/bin/winapps:841-852.
          "winapps/apps".source = "${winappsPkg}/src/apps";
        };
    };
  };
}
