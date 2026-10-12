{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.apps.python;
in
{
  options.apps.python.enable = lib.mkEnableOption "Python with tkinter, for running GUI scripts from a venv";

  config = lib.mkIf cfg.enable {
    # nixpkgs splits tkinter out of the interpreter, so a venv made from the
    # bare python3 has no _tkinter. hiPrio: niri also puts a bare python3 on
    # PATH and this one has to win.
    environment.systemPackages = [
      (lib.hiPrio (pkgs.python3.withPackages (ps: [ ps.tkinter ])))
    ];
  };
}
