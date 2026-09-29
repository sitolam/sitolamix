{ lib, ... }:
{
  # Part of the baseline, not a suite: the sops secrets in ./sops.nix decrypt
  # with this machine's SSH host key (/etc/ssh/ssh_host_ed25519_key,
  # converted to age), and nothing else generates one. Enabling openssh makes
  # NixOS responsible for creating and keeping it. Losing it makes
  # secrets/*.yaml undecryptable, so back it up (see README -> Secrets).
  services.openssh = {
    enable = true;

    settings = {
      # Key-only: a listening sshd with password auth is a brute-force
      # target on any network this desktop joins.
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Opens the LAN listener explicitly rather than inheriting it silently —
  # set false to keep host-key generation but drop the listener.
  networking.firewall.allowedTCPPorts = lib.mkDefault [ 22 ];

  # No authorized keys declared: until one is added, nobody can log in — the
  # safe default, not a bug.
  #   users.users.otis.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
}
