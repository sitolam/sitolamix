{ config, lib, ... }:
let
  cfg = config.apps.gpu-screen-recorder;
in
{
  options.apps.gpu-screen-recorder.enable = lib.mkEnableOption "GPU Screen Recorder (GTK)";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          gpu-screen-recorder
          gpu-screen-recorder-gtk
        ];
      };
  };
}
