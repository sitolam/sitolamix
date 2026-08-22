{ config, lib, ... }:
let
  cfg = config.apps.cco;
in
{
  # `cco` is to OmniRoute what `ccl` is to LM Studio: a launcher, not a wrapper.
  # Plain `claude` keeps talking to Anthropic on the subscription, and only a
  # session started through `cco` is routed at the gateway. A wrapper named
  # `claude` earlier on PATH was the alternative and was rejected — it would
  # silently move every session, including the ones meant to burn subscription
  # quota, and leave no obvious way back.
  options.apps.cco.enable = lib.mkEnableOption "cco (launch Claude Code against the local OmniRoute gateway)";

  config = lib.mkIf cfg.enable {
    # cco execs `claude`, so the plugin set that module pins is what these
    # sessions get too.
    apps.claude-code.enable = true;
    # The gateway has to be up before cco can hand off; it health-checks and
    # refuses rather than starting anything itself.
    services.omniroute.enable = true;

    home.extraOptions =
      { pkgs, ... }:
      let
        cco = pkgs.writeShellApplication {
          name = "cco";
          runtimeInputs = with pkgs; [
            curl
            jq
            coreutils # tr
            claude-code
          ];
          # The port lives in one place (services.omniroute.port) and reaches the
          # script from there. `:=` rather than a plain assignment so an explicit
          # CCO_BASE_URL in the environment still wins — that is how you point cco
          # at a remote OmniRoute.
          text = ''
            : "''${CCO_BASE_URL:=http://127.0.0.1:${toString config.services.omniroute.port}}"

            ${builtins.readFile ./cco.sh}
          '';
        };
      in
      {
        home.packages = [ cco ];
      };
  };
}
