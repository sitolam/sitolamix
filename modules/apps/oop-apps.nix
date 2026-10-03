{ config, lib, ... }:
let
  cfg = config.apps.oop-apps;
in
{
  options.apps.oop-apps.enable = lib.mkEnableOption "BlueJ/Greenfoot OOP course apps";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      let
        glassOpens = "--add-opens javafx.graphics/com.sun.glass.ui=ALL-UNNAMED";
      in
      {
        home.packages = with pkgs; [
          jdk25 # course requires Java >= 21; jdk25 is latest LTS-track release
          bluej # course requires >= 5.5.0
          # nixpkgs' greenfoot lacks the scene.input --add-opens its bluej has:
          # every editor open or "Set image" dies with IllegalAccessError, so
          # actors keep the Greenfoot logo. It must be a JVM flag, before -cp.
          # Drop once the nixpkgs wrapper carries it.
          (greenfoot.overrideAttrs (old: {
            installPhase =
              builtins.replaceStrings
                [ glassOpens ]
                [
                  "${glassOpens} --add-opens javafx.graphics/com.sun.javafx.scene.input=ALL-UNNAMED"
                ]
                old.installPhase;
          })) # course requires >= 3.9.0
        ];
      };
  };
}
