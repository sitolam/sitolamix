{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.apps.helium;

  # Helium's own Web Store update pings never carry `prodversion`, which
  # makes clients2.google.com answer "noupdate" for every extension no
  # matter how ExtensionSettings is configured — verified by hand: the same
  # ping with `&prodversion=151` (helium's own Chrome/151 UA version)
  # returns a real codebase URL, without it, "noupdate". This is a bug in
  # helium's build, not something a policy can route around, so route
  # through a local proxy that patches the ping instead. See update-proxy.py.
  updateProxyPort = 8791;
  webstore = "http://127.0.0.1:${toString updateProxyPort}/service/update2/crx";

  # Chrome Web Store IDs of every extension this profile carries. Listing them
  # here is what makes the browser reproducible: helium pulls them from the
  # store on the first start of a *fresh* profile, so the extension set travels
  # with the flake instead of with ~/.config/net.imput.helium.
  #
  # "normal_installed" installs and pins the extension while still letting the
  # extensions page disable it; "force_installed" would also take away the
  # on/off switch, which is more lockdown than we want on a personal machine.
  #
  # `pin` decides whether the extension gets a permanent toolbar button
  # (`toolbar_pin = "force_pinned"`). Toolbar pinning otherwise lives in the
  # profile, so it is exactly the kind of state this module exists to own.
  # Only the two worth a one-click button are pinned; everything else is left
  # at Chromium's default — unpinned, still reachable from the puzzle menu and
  # still pinnable by hand. A floor, not a cage.
  extensions = {
    "cjpalhdlnbpafiamejdnhcphjbkeiagm" = {
      name = "uBlock Origin";
      # Deliberately the Web Store build rather than helium's compiled-in uBO.
      # The store still serves the full MV2 extension despite the MV2 sunset
      # (verified 2026-08-26: the update ping answers with a 1.74.0 codebase
      # URL), and it keeps its own filter lists and settings instead of
      # helium's fork of them.
      #
      # Helium's built-in copy has no policy and no pref that turns it off —
      # only the Settings > Services > uBlock switch — so that one has to be
      # flipped by hand once per profile. Running both at once means two
      # element pickers and two sets of cosmetic filters on every page.
      pin = false;
    };
    "dhdgffkkebhmkfjojejmpbldmpobfkfo" = {
      name = "Tampermonkey";
      pin = false;
    };
    "dpacanjfikmhoddligfbehkpomnbgblf" = {
      name = "AHA Music - Song Finder";
      pin = false;
    };
    "ekhagklcjbdpajgpjgmbionohlpdbjgc" = {
      name = "Zotero Connector";
      pin = true;
    };
    "elfaihghhjjoknimpccccmkioofjjfkf" = {
      name = "StayFree - Website Blocker & Web Analytics";
      pin = false;
    };
    "fcoeoabgfenejglbffodgkkbkcdhcgfn" = {
      name = "Claude";
      pin = false;
    };
    "mfpiaehgjbbfednooihadalhehabhcjo" = {
      name = "Scrolling Screenshot Tool";
      pin = false;
    };
    "nngceckbapebfimnlniiiahkandclblb" = {
      name = "Bitwarden Password Manager";
      pin = true;
    };
  };

  # Extensions this profile must NOT carry. Deleting an id from `extensions`
  # above is not enough to get rid of one: the "*" catch-all below is
  # `allowed`, so an extension already sitting in ~/.config/net.imput.helium
  # from an earlier generation simply stops being managed and keeps running.
  # `removed` is the mode that actually uninstalls it and blocks a reinstall,
  # so an id has to stay named here for as long as any profile might still
  # have it. Drop a row only after every machine has rebuilt past it.
  removedExtensions = {
    "bdhficnphioomdjhdfbhdepjgggekodf" = "Smartschool++";
    "epjdekbdhhhpkpkclookegeabjkpblch" = "Smartschool Grid - Percentages";
    "lbpdknjafmmnemenflppkofaakldbfom" = "Smarter Smartschool";
    # Was briefly the screenshot extension here; Scrolling Screenshot Tool
    # replaced it, and this one has to be named to get it back out of the
    # profiles that already installed it.
    "mcbpblocgmgfnpjjppndjkmgjaogfceg" = "GoFullPage - Full Page Screen Capture";
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
    systemd.services.helium-extension-update-proxy = {
      description = "Prodversion-patching proxy for Helium's Chrome Web Store update pings";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 ${./update-proxy.py}";
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

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
          lib.mapAttrs (
            _: ext:
            {
              installation_mode = "normal_installed";
              update_url = webstore;
            }
            // lib.optionalAttrs ext.pin { toolbar_pin = "force_pinned"; }
          ) extensions
          // lib.mapAttrs (_: _: { installation_mode = "removed"; }) removedExtensions
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
