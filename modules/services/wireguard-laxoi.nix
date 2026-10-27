{ config, lib, ... }:
let
  cfg = config.services.wireguard-laxoi;
  envPath = config.sops.secrets.wireguard_laxoi_env.path;
in
{
  options.services.wireguard-laxoi = {
    enable = lib.mkEnableOption ''
      Laxoi (home) WireGuard tunnel as a NetworkManager connection, toggleable
      from DMS's control center (builtin_vpn widget)
    '';
  };

  config = lib.mkIf cfg.enable {
    # Private key and endpoint (home IP) are secret; peer pubkey and tunnel
    # address below are not.
    sops.secrets.wireguard_laxoi_env = {
      sopsFile = ../../secrets/wireguard.yaml;
      mode = "0400";
    };

    # ensureProfiles envsubst-expands $WG_* into the profile it
    # writes to /run/NetworkManager/system-connections/, never the Nix store.
    networking.networkmanager.ensureProfiles = {
      environmentFiles = [ envPath ];
      profiles = {
        laxoi = {
          connection = {
            id = "laxoi";
            type = "wireguard";
            interface-name = "laxoi";
            # Off by default; toggled from DMS's control center.
            autoconnect = false;
          };
          wireguard = {
            private-key = "$WG_PRIVATE_KEY";
            mtu = 1420;
          };
          "wireguard-peer.fjr5K4p6NLC0wHkNRq4Rs4r6yz0GhdzsMdzCQaPaPHA=" = {
            endpoint = "$WG_ENDPOINT";
            allowed-ips = "0.0.0.0/0";
            persistent-keepalive = 21;
          };
          ipv4 = {
            method = "manual";
            address1 = "10.0.0.7/32";
            dns = "192.168.68.53";
          };
          ipv6.method = "disabled";
        };
      };
    };
  };
}
