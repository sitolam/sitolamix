{ inputs, ... }:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # Secrets live encrypted (age) in ./secrets and are decrypted at activation to
  # /run/secrets/<name> (tmpfs), never touching the nix store or git in plaintext.
  # The decryption key is the machine's SSH host key (converted to age).
  sops = {
    defaultSopsFile = ../../secrets/home-assistant.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # Home Assistant long-lived token, readable by the user running DMS.
    secrets.hass_token = {
      owner = "otis";
      mode = "0400";
    };
  };
}
