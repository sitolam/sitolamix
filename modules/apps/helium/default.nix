{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.apps.helium;

  # Helium's update pings never carry prodversion, so Google answers
  # "noupdate" for every extension. Proxy patches the ping (update-proxy.py).
  updateProxyPort = 8791;
  webstore = "http://127.0.0.1:${toString updateProxyPort}/service/update2/crx";

  # Web Store ids pulled on first launch of a fresh profile. `pin` adds a
  # forced toolbar button; only the two worth one-click get it.
  extensions = {
    "cjpalhdlnbpafiamejdnhcphjbkeiagm" = {
      name = "uBlock Origin";
      # Store build serves full MV2 (checked 2026-08-26); helium's built-in
      # copy has no disable policy, so turn it off by hand once per profile.
      pin = false;
    };
    "dedjgknigfeelejglamclffonmophnfl" = {
      name = "yt-dlp";
      # Needs apps.ytdlp-download's native-messaging host; harmless without it.
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

  # Extensions to force-uninstall. Just deleting an id from `extensions`
  # isn't enough: the catch-all below is `allowed`, so it'd stay installed.
  # Keep an id here until every profile has rebuilt past it.
  removedExtensions = {
    "bdhficnphioomdjhdfbhdepjgggekodf" = "Smartschool++";
    "epjdekbdhhhpkpkclookegeabjkpblch" = "Smartschool Grid - Percentages";
    "lbpdknjafmmnemenflppkofaakldbfom" = "Smarter Smartschool";
    "mcbpblocgmgfnpjjppndjkmgjaogfceg" = "GoFullPage - Full Page Screen Capture";
  };

  # Wraps a userscript as a minimal MV3 extension: Tampermonkey keeps scripts
  # in the profile's LevelDB, which nix can't seed. world = "MAIN" reproduces
  # `@grant none`.
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
      # https://github.com/LaptopCat/AutoBSC — vendored; re-vendor by hand to update.
      script = ./userscripts/autobsc.user.js;
      matches = [ "https://event.supercell.com/brawlstars/*" ];
    })
  ];

  # Unpacked theme extension matugen renders on wallpaper change (see
  # theming.matugen.templates.helium below); helium re-reads it on next launch.
  themeDir = "${config.users.users.otis.home}/.local/state/sitolamix/helium-theme";
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
        # explicit: without it touchpad scroll falls back to Xwayland's jumpy steps
        "--ozone-platform=wayland"
        "--enable-smooth-scrolling"
        "--enable-features=VaapiVideoDecoder,Vulkan,VulkanFromANGLE,DefaultANGLEVulkan"
        # only way to load unpacked extensions: policy install needs a Web Store id
        "--load-extension=${lib.concatMapStringsSep "," toString (userscripts ++ [ themeDir ])}"
      ];

      # This build reads /etc/chromium/policies/managed (/etc/opt/chrome is
      # native-messaging only).
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
            # without this catch-all, naming any id blocks every unnamed one too
            "*".installation_mode = "allowed";
          };

        # suppresses --load-extension's launch nag bar and dev-mode bubble
        CommandLineFlagSecurityWarningsEnabled = false;
        ExtensionDeveloperModeSettings = 0;

        # merges into the user's own list rather than replacing it
        SpellcheckLanguage = [
          "nl"
          "en-US"
        ];
      };
    };

    # Chrome theme extension, not GTK mode: GTK paints the active tab
    # indistinguishable from the rest (tested 2026-09-27, 0.18.1.1). Helium
    # also maps theme keys oddly — ignores `frame`, uses `toolbar` for both
    # frame and active tab, draws inactive tabs as pills in `background_tab`.
    # Drop once GTK active-tab is fixed: imputnet/helium-linux#131, imputnet/helium#1850.
    theming.matugen.templates.helium = {
      input = ./theme-manifest.json;
      output = "${themeDir}/manifest.json";
    };

    home.extraOptions =
      { lib, ... }:
      {
        # Helium's ungoogled-chromium base never fetches Widevine (DRM); point
        # this hint file at nixpkgs' widevine-cdm instead. Drop if helium ever
        # bundles it itself.
        xdg.configFile."net.imput.helium/WidevineCdm/latest-component-updated-widevine-cdm".text =
          builtins.toJSON
            {
              Path = "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm";
            };

        # Seed an empty but valid theme so --load-extension has somewhere to
        # point before DMS's first render; never overwrite once it has one.
        home.activation.heliumThemeSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ ! -e "${themeDir}/manifest.json" ]; then
            run mkdir -p "${themeDir}"
            run sh -c 'printf "%s\n" "$1" > "$2"' -- \
              '{"manifest_version":3,"name":"sitolamix wallpaper theme","version":"1.0","theme":{}}' \
              "${themeDir}/manifest.json"
          fi
        '';
      };
  };
}
