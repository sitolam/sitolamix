{ config, lib, ... }:
let
  cfg = config.apps.ccl;
in
{
  options.apps.ccl.enable = lib.mkEnableOption "ccl (launch Claude Code against an LM Studio model)";

  config = lib.mkIf cfg.enable {
    # ccl execs `ccr code`, which in turn launches claude — and the plugin set
    # that module pins is the one those sessions get too.
    apps.claude-code.enable = true;

    home.extraOptions =
      { pkgs, ... }:
      let
        ccl = pkgs.writeShellApplication {
          name = "ccl";
          runtimeInputs = with pkgs; [
            curl
            jq
            fzf
            util-linux # column, setsid
            coreutils # sha256sum, seq, ...
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
          # ccr must be on PATH for the user too, so it stays usable on its own;
          # `claude` itself comes from apps.claude-code.
          pkgs.claude-code-router
        ];
      };
  };
}
