{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.apps.helium;

  webstore = "https://clients2.google.com/service/update2/crx";

  # Chrome Web Store IDs of every extension this profile carries. Listing them
  # here is what makes the browser reproducible: helium pulls them from the
  # store on the first start of a *fresh* profile, so the extension set travels
  # with the flake instead of with ~/.config/net.imput.helium.
  #
  # "normal_installed" installs and pins the extension while still letting the
  # extensions page disable it; "force_installed" would also take away the
  # on/off switch, which is more lockdown than we want on a personal machine.
  extensions = {
    "bdhficnphioomdjhdfbhdepjgggekodf" = "Smartschool++";
    "dhdgffkkebhmkfjojejmpbldmpobfkfo" = "Tampermonkey";
    "dpacanjfikmhoddligfbehkpomnbgblf" = "AHA Music - Song Finder";
    "ekhagklcjbdpajgpjgmbionohlpdbjgc" = "Zotero Connector";
    "epjdekbdhhhpkpkclookegeabjkpblch" = "Smartschool Grid - Percentages";
    "fcoeoabgfenejglbffodgkkbkcdhcgfn" = "Claude";
    "lbpdknjafmmnemenflppkofaakldbfom" = "Smarter Smartschool";
    "nngceckbapebfimnlniiiahkandclblb" = "Bitwarden Password Manager";
  };

  # Wraps a Tampermonkey-style userscript into a minimal MV3 extension that
  # helium loads with --load-extension. Tampermonkey keeps its scripts in the
  # profile's LevelDB — exactly the mutable state this module exists to get rid
  # of, and there is no policy that can seed it. An extension, on the other
  # hand, is just a directory of files, which nix can build.
  #
  # world = "MAIN" reproduces `@grant none`: the script runs in the page's own
  # JS context. An isolated content script could not patch window.WebSocket,
  # which is the whole trick AutoBSC relies on. run_at = document_start matches
  # Tampermonkey's default for such scripts — the hook has to be in place
  # before the page opens its socket.
  mkUserscript =
    {
      name,
      version,
      matches,
      script,
      runAt ? "document_start",
    }:
    pkgs.runCommand "helium-userscript-${name}"
      {
        manifest = builtins.toJSON {
          manifest_version = 3;
          name = "Userscript: ${name}";
          inherit version;
          content_scripts = [
            {
              inherit matches;
              js = [ "userscript.js" ];
              run_at = runAt;
              world = "MAIN";
              all_frames = false;
            }
          ];
        };
        passAsFile = [ "manifest" ];
      }
      ''
        mkdir -p $out
        cp ${script} $out/userscript.js
        cp $manifestPath $out/manifest.json
      '';

  userscripts = [
    (mkUserscript {
      name = "AutoBSC";
      version = "0.3.1";
      # https://github.com/LaptopCat/AutoBSC — vendored next to this module
      # rather than fetched, so a rebuild never depends on the upstream repo
      # still being there. Re-vendor the file by hand to update it.
      script = ./userscripts/autobsc.user.js;
      matches = [ "https://event.supercell.com/brawlstars/*" ];
    })
  ];
in
{
  imports = [ inputs.helium.nixosModules.default ];

  options.apps.helium.enable = lib.mkEnableOption "Helium browser (declarative flags, policies, extensions)";

  config = lib.mkIf cfg.enable {
    programs.helium = {
      enable = true;

      flags = [
        # niri exports the ozone env vars, but be explicit: without native
        # wayland helium falls back to Xwayland, where touchpad scroll arrives
        # as discrete/jumpy steps instead of smooth, niri-scaled axis events.
        "--ozone-platform=wayland"
        "--enable-smooth-scrolling"
        # Hardware video decode + the Vulkan-backed ANGLE path.
        "--enable-features=VaapiVideoDecoder,Vulkan,VulkanFromANGLE,DefaultANGLEVulkan"
        # Unpacked extensions can only arrive this way: policy install wants a
        # Web Store id, and Chromium's standalone-external-extension directory
        # is the compiled-in /usr/share/chromium/extensions, which NixOS has no
        # business creating.
        "--load-extension=${lib.concatMapStringsSep "," toString userscripts}"
      ];

      # Chrome Enterprise policies, written to /etc/chromium/policies/managed —
      # which is the directory this build of helium actually reads (verified in
      # the binary; /etc/opt/chrome is only used for native messaging hosts).
      # This is also why the module can no longer live in the old FHS/bwrap
      # packaging: that sandbox never bound /etc/chromium, so policies were
      # invisible to the browser.
      policies = {
        ExtensionSettings =
          lib.mapAttrs (_: _: {
            installation_mode = "normal_installed";
            update_url = webstore;
          }) extensions
          // {
            # Without this catch-all, naming any id in ExtensionSettings blocks
            # every id that is *not* named — including themes and anything
            # installed by hand ("… is blocked by the administrator" in the
            # extension log). The declared set is meant to be a floor, not a
            # whitelist.
            "*".installation_mode = "allowed";
          };

        # --load-extension trips two nags on every launch otherwise: the yellow
        # "unsupported command-line flag" bar, and the "turn off developer mode
        # extensions" bubble. Setting the developer-mode policy explicitly to
        # Allow (0) is what suppresses the second one.
        CommandLineFlagSecurityWarningsEnabled = false;
        ExtensionDeveloperModeSettings = 0;
      };
    };
  };
}
