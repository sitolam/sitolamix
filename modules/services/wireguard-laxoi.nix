{ config, lib, ... }:
let
  cfg = config.services.wireguard-laxoi;
  envPath = config.sops.secrets.wireguard_laxoi_env.path;
in
{
  options.services.wireguard-laxoi = {
    enable = lib.mkEnableOption ''
      Laxoi (home) WireGuard tunnel as a NetworkManager connection, toggleable
      from DMS's control center (see modules/desktop/dms/bar.nix's builtin_vpn
      widget). Peer/address/DNS came from the wg-quick .conf DMS's VPN import
      produced; only the private key is secret.
    '';
  };

  config = lib.mkIf cfg.enable {
    # Only the private key is sensitive — peer public key, endpoint and
    # address below are not, and live in the profile in plain sight.
    sops.secrets.wireguard_laxoi_env = {
      sopsFile = ../../secrets/wireguard.yaml;
      mode = "0400";
    };

    # ensureProfiles envsubst-expands $WG_PRIVATE_KEY (from environmentFiles)
    # into the profile it writes to /run/NetworkManager/system-connections/,
    # never the Nix store. This profile replaces the one DMS's VPN import
    # created by hand in /etc/NetworkManager/system-connections/sitolamix.nmconnection
    # — delete that file (or `nmcli connection delete sitolamix`) once this is
    # switched in, or NetworkManager ends up with two connections of the same
    # name.
    networking.networkmanager.ensureProfiles = {
      environmentFiles = [ envPath ];
      profiles = {
        laxoi = {
          connection = {
            id = "laxoi";
            type = "wireguard";
            interface-name = "laxoi";
            # Off by default — toggle from DMS's control center (builtin_vpn
            # tile). autoconnect=true would bring it up at boot/NM-reload.
            autoconnect = false;
          };
          wireguard = {
            private-key = "$WG_PRIVATE_KEY";
            mtu = 1420;
          };
          "wireguard-peer.fjr5K4p6NLC0wHkNRq4Rs4r6yz0GhdzsMdzCQaPaPHA=" = {
            endpoint = "94.110.158.149:51820";
            allowed-ips = "0.0.0.0/0";
            persistent-keepalive = 21;
          };
          ipv4 = {
            method = "manual";
            address1 = "10.0.0.7/32";
            dns = "192.168.68.138";
          };
          ipv6.method = "disabled";
        };
      };
    };
  };
}
