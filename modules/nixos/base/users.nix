_:
{
  flake.modules.nixos.base =
    { pkgs, ... }:
    {
      users.users.otis = {
        isNormalUser = true;
        description = "otis";
        extraGroups = [
          "wheel"
          "networkmanager"
          "video"
          "audio"
          "docker"
          "input"
          "uinput"
        ];
        shell = pkgs.fish;
      };

      programs.fish.enable = true;
    };
}
