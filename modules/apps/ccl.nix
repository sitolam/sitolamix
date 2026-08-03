{ config, lib, ... }:
let
  cfg = config.apps.ccl;
in
{
  options.apps.ccl.enable = lib.mkEnableOption "ccl (launch Claude Code against an LM Studio model)";

  config = lib.mkIf cfg.enable {
    home.extraOptions =
      { pkgs, ... }:
      let
        ccl = pkgs.writeShellApplication {
          name = "ccl";
          runtimeInputs = with pkgs; [
            curl
            jq
            fzf
            util-linux # column
            claude-code
            claude-code-router
          ];
          # Pin the claude binary rather than letting the router resolve it from PATH,
          # so ccl works the same from a bare shell as from an interactive login.
          text = ''
            export CLAUDE_PATH="${pkgs.claude-code}/bin/claude"

            ${builtins.readFile ./ccl.sh}
          '';
        };
      in
      {
        home.packages = [
          ccl
          # ccl execs `ccr code`, which in turn launches claude. Both must be on PATH
          # for the user too, so `ccr`/`claude` remain usable on their own.
          pkgs.claude-code
          pkgs.claude-code-router
        ];
      };
  };
}
