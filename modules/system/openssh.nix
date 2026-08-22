{ lib, ... }:
{
  # Always on, and deliberately part of the baseline rather than a suite: the
  # sops secrets in ./sops.nix are decrypted with this machine's SSH **host**
  # key (`/etc/ssh/ssh_host_ed25519_key`, converted to age), and nothing else in
  # the config generates one. Without sshd that file only ever existed because
  # some earlier install happened to make it — a load-bearing accident. Enabling
  # openssh makes NixOS responsible for creating and keeping it.
  #
  # Host keys are generated once and preserved across rebuilds; NixOS never
  # replaces an existing one. Losing it makes secrets/*.yaml undecryptable on
  # this machine, so it belongs in a backup (see README → Secrets).
  services.openssh = {
    enable = true;

    settings = {
      # Key-only. A desktop with a listening sshd and password auth is a
      # brute-force target on any network it joins; nothing here needs
      # passwords over the wire.
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # sshd listens on the LAN by default (services.openssh.openFirewall). That is
  # wanted here — remote shell into the workstation — but it is the part that
  # actually exposes the machine, so it is spelled out rather than inherited
  # silently. Set this false to keep the host-key generation and drop the
  # listener.
  networking.firewall.allowedTCPPorts = lib.mkDefault [ 22 ];

  # No authorized keys are declared here. Until you add one, key-only auth means
  # nobody can log in at all — which is the safe default, not a bug:
  #
  #   users.users.otis.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
}
