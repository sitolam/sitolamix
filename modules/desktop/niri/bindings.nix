{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.niri.enable {
    home.extraOptions =
      let
        noArg = action: { action.${action} = [ ]; };
        withArg = action: value: { action.${action} = value; };
        spawn = command: { action.spawn = command; };
        dms =
          command:
          [
            "dms"
            "ipc"
            "call"
          ]
          ++ command;

        mkDirectionalBinds =
          modifier:
          {
            left,
            down,
            up,
            right,
          }:
          {
            "${modifier}+Left" = noArg left;
            "${modifier}+Down" = noArg down;
            "${modifier}+Up" = noArg up;
            "${modifier}+Right" = noArg right;
            "${modifier}+H" = noArg left;
            "${modifier}+J" = noArg down;
            "${modifier}+K" = noArg up;
            "${modifier}+L" = noArg right;
          };

        mkWorkspaceNumberBinds =
          modifier: action:
          builtins.listToAttrs (
            map (workspace: {
              name = "${modifier}+${toString workspace}";
              value = withArg action workspace;
            }) (lib.range 1 9)
          );

        mkScrollBinds =
          modifier:
          {
            left,
            right,
            up,
            down,
          }:
          {
            "${modifier}+WheelScrollDown" = {
              cooldown-ms = 150;
              action.${down} = [ ];
            };
            "${modifier}+WheelScrollUp" = {
              cooldown-ms = 150;
              action.${up} = [ ];
            };
            "${modifier}+WheelScrollRight" = noArg right;
            "${modifier}+WheelScrollLeft" = noArg left;
          };
      in
      {
        programs.niri.settings.binds = lib.mkMerge [
          {
            # DankMaterialShell panels (dms ipc)
            # omarchy-style root menu (dankMenu plugin, see ../dms/plugins.nix):
            # one key to every command, with its own search and app list. This
            # replaces DMS's spotlight as the general launcher — spotlight is
            # still reachable for its trigger-based plugins, see Mod+Shift+Period.
            # The `dms` helper above already prepends `ipc call`.
            "Mod+Space" = spawn (dms [
              "dankMenu"
              "toggle"
              "root"
            ]);
            "Mod+V" = spawn (dms [
              "clipboard"
              "toggle"
            ]);
            "Mod+Slash" = spawn (dms [
              "keybinds"
              "toggleBinds"
            ]);
            "Mod+P" = spawn (dms [
              "notepad"
              "toggle"
            ]);
            # dashboard/overview panel (dank dash)
            "Mod+D" = spawn (dms [
              "dash"
              "toggle"
            ]);
            # emoji / unicode picker (emojiLauncher plugin, trigger ":e"): open
            # spotlight pre-filled with the trigger so it lands straight on the
            # emoji search. Trailing space is intentional (starts the filter).
            "Mod+Shift+Period" = spawn (dms [
              "spotlight"
              "toggleQuery"
              ":e "
            ]);
            # F2's icon on this keyboard: a plain literal F-key (confirmed via
            # evtest as KEY_F2), not a dedicated media/XF86 key like F6-F11 —
            # so it's Mod+F2 rather than bare F2, to avoid shadowing F2 in
            # every app that binds it directly (rename, suspend-card, etc).
            "Mod+F2" = spawn (dms [
              "spotlight"
              "toggleQuery"
              ":e "
            ]);
            # Mod+S / Mod+M are the scratchpad (see below); control-center and
            # processlist moved here (control-center is also the bar button).
            "Mod+Ctrl+S" = spawn (dms [
              "control-center"
              "toggle"
            ]);
            "Mod+N" = spawn (dms [
              "notifications"
              "toggle"
            ]);
            "Mod+Ctrl+M" = spawn (dms [
              "processlist"
              "toggle"
            ]);

            # scratchpad (argosnothing/niri-scratchpad-rs). `create 1` toggles
            # register 1: it stashes the focused window to the "stash" workspace
            # and shows it back as a float. Same command on both keys, used as a
            # pair: Mod+M to minimise, Mod+S to bring it back. --as-float so the
            # shown scratchpad floats over its workspace.
            "Mod+M" = spawn [
              "niri-scratchpad"
              "create"
              "1"
              "--as-float"
            ];
            "Mod+S" = spawn [
              "niri-scratchpad"
              "create"
              "1"
              "--as-float"
            ];

            # session
            "Mod+BackSpace" = spawn (dms [
              "lock"
              "lock"
            ]);
            # on-demand lock + suspend (swayidle also locks before sleep, but
            # this locks explicitly first so we never flash the desktop).
            "Mod+Shift+BackSpace" = spawn [
              "sh"
              "-c"
              "loginctl lock-session && systemctl suspend"
            ];
            # built-in DMS power menu (option shortcuts patched to numbers in
            # modules/desktop/dms/default.nix)
            "Mod+Ctrl+BackSpace" = spawn (dms [
              "powermenu"
              "toggle"
            ]);

            # theme control
            "Mod+Shift+T" = spawn (dms [
              "theme"
              "toggle"
            ]);
            "Mod+Shift+W" = spawn (dms [
              "dankdash"
              "wallpaper"
            ]);
            "Mod+Alt+N" = spawn (dms [
              "night"
              "toggle"
            ]);

            # media / volume — wpctl (wireplumber), not pactl: this system has
            # no pulseaudio-utils installed at all, so every pactl invocation
            # here silently failed (127, command not found) until caught live.
            # wpctl ships with pipewire/wireplumber (audio.nix), so no new
            # package is needed.
            "XF86AudioRaiseVolume" = spawn [
              "wpctl"
              "set-volume"
              "@DEFAULT_AUDIO_SINK@"
              "5%+"
            ];
            "XF86AudioLowerVolume" = spawn [
              "wpctl"
              "set-volume"
              "@DEFAULT_AUDIO_SINK@"
              "5%-"
            ];
            "XF86AudioMute" = spawn [
              "wpctl"
              "set-mute"
              "@DEFAULT_AUDIO_SINK@"
              "toggle"
            ];
            # F9's icon on this keyboard (mic-mute) — raw scancode confirmed via
            # evtest as KEY_MICMUTE, which xkeyboard-config's evdev "inet" rules
            # map to this keysym.
            "XF86AudioMicMute" = spawn [
              "wpctl"
              "set-mute"
              "@DEFAULT_AUDIO_SOURCE@"
              "toggle"
            ];
            "XF86AudioPlay" = spawn [
              "playerctl"
              "play-pause"
            ];
            "XF86AudioNext" = spawn [
              "playerctl"
              "next"
            ];
            "XF86AudioPrev" = spawn [
              "playerctl"
              "previous"
            ];
            # internal panel (no device arg = DMS's default, which is the
            # eDP backlight whenever the internal panel is active) plus both
            # external monitors (DMS controls one DDC device per call and has
            # no "all" target). ddc:i2c-5 = HDMI-A-1, ddc:i2c-6 = DP-3 — if the
            # i2c bus numbers ever shift, update these (ddcutil detect).
            # The trailing "" is required, not optional — dms ipc's transport
            # enforces the QML handler's full arity (increment(step, device)),
            # so a bare `dms ipc call brightness increment 5` errors with "Too
            # few arguments" instead of falling back to the default device.
            "XF86MonBrightnessUp" = spawn [
              "sh"
              "-c"
              ''dms ipc call brightness increment 5 ""; dms ipc call brightness increment 5 ddc:i2c-5; dms ipc call brightness increment 5 ddc:i2c-6''
            ];
            "XF86MonBrightnessDown" = spawn [
              "sh"
              "-c"
              ''dms ipc call brightness decrement 5 ""; dms ipc call brightness decrement 5 ddc:i2c-5; dms ipc call brightness decrement 5 ddc:i2c-6''
            ];

            # apps
            "Mod+T" = {
              hotkey-overlay.title = "Open a terminal";
              action.spawn = "ghostty";
            };
            "Mod+B" = spawn "helium";
            "Mod+E" = spawn "nautilus";
            "Mod+Shift+G" = spawn [
              "ghostty"
              "-e"
              "lazygit"
            ];
            "Mod+Shift+M" = spawn [
              "ghostty"
              "-e"
              "btop"
            ];

            # window ops
            "Mod+Q" = noArg "close-window";
            "Mod+O" = {
              repeat = false;
              action.toggle-overview = [ ];
            };
            # F11's icon on this keyboard (blank/unlabeled) — raw scancode
            # confirmed via evtest as KEY_PROG2 -> XF86Launch2. Free key, so it
            # gets the same action as Mod+O.
            "XF86Launch2" = {
              repeat = false;
              action.toggle-overview = [ ];
            };
            "Mod+R" = noArg "switch-preset-column-width";
            "Mod+Shift+R" = noArg "switch-preset-window-height";
            "Mod+Ctrl+R" = noArg "reset-window-height";
            "Mod+F" = noArg "maximize-column";
            "Mod+Shift+F" = noArg "fullscreen-window";
            "Mod+Ctrl+F" = noArg "expand-column-to-available-width";
            "Mod+C" = noArg "center-column";
            "Mod+Ctrl+C" = noArg "center-visible-columns";
            "Mod+Minus" = withArg "set-window-width" "-10%";
            "Mod+Equal" = withArg "set-window-width" "+10%";
            "Mod+Shift+Minus" = withArg "set-window-height" "-10%";
            "Mod+Shift+Equal" = withArg "set-window-height" "+10%";
            "Mod+W" = noArg "toggle-window-floating";
            "Mod+Alt+W" = noArg "switch-focus-between-floating-and-tiling";
            "Mod+A" = noArg "toggle-column-tabbed-display";
            "Mod+Ctrl+Space" = spawn [
              "nsticky"
              "sticky"
              "toggle-active"
            ];

            # column consume/expel
            "Mod+BracketLeft" = noArg "consume-or-expel-window-left";
            "Mod+BracketRight" = noArg "consume-or-expel-window-right";
            "Mod+Comma" = noArg "consume-window-into-column";
            "Mod+Period" = noArg "expel-window-from-column";

            # workspace nav (extra)
            "Mod+Home" = noArg "focus-column-first";
            "Mod+End" = noArg "focus-column-last";
            "Mod+Ctrl+Home" = noArg "move-column-to-first";
            "Mod+Ctrl+End" = noArg "move-column-to-last";
            "Mod+Page_Down" = noArg "focus-workspace-down";
            "Mod+Page_Up" = noArg "focus-workspace-up";
            "Mod+U" = noArg "focus-workspace-up";
            "Mod+I" = noArg "focus-workspace-down";
            "Mod+Ctrl+Page_Down" = noArg "move-column-to-workspace-down";
            "Mod+Ctrl+Page_Up" = noArg "move-column-to-workspace-up";
            "Mod+Ctrl+U" = noArg "move-column-to-workspace-up";
            "Mod+Ctrl+I" = noArg "move-column-to-workspace-down";
            "Mod+Shift+Page_Down" = noArg "move-workspace-down";
            "Mod+Shift+Page_Up" = noArg "move-workspace-up";
            "Mod+Shift+U" = noArg "move-workspace-up";
            "Mod+Shift+I" = noArg "move-workspace-down";
            "Mod+Tab" = noArg "focus-workspace-previous";

            # screenshots
            # screen capture + record toolbar (screenCaptureToolbar plugin);
            # replaces niri's built-in region UI here. Print/Ctrl+Print/Alt+Print
            # and the grim region/OCR/color binds below are left as-is.
            "Mod+Shift+S" = spawn (dms [
              "screenCaptureToolbar"
              "toggle"
            ]);
            "Ctrl+Print" = noArg "screenshot-screen";
            "Alt+Print" = noArg "screenshot-window";
            "Print" = noArg "screenshot";

            # region screenshot / OCR / color-pick -> clipboard
            "Mod+Print" = spawn [
              "sh"
              "-c"
              "grim -g \"$(slurp)\" - | wl-copy"
            ];
            "Mod+Shift+O" = spawn [
              "sh"
              "-c"
              "grim -g \"$(slurp)\" - | tesseract - - | wl-copy"
            ];
            "Mod+Shift+C" = spawn [
              "sh"
              "-c"
              "hyprpicker -a"
            ];

            # session-level
            "Mod+Escape" = {
              allow-inhibiting = false;
              action.toggle-keyboard-shortcuts-inhibit = [ ];
            };
            "Mod+Shift+E" = noArg "quit";
            "Ctrl+Alt+Delete" = noArg "quit";
            "Mod+Shift+P" = noArg "power-off-monitors";
          }

          (mkDirectionalBinds "Mod" {
            left = "focus-column-left";
            down = "focus-window-down";
            up = "focus-window-up";
            right = "focus-column-right";
          })

          (mkDirectionalBinds "Mod+Ctrl" {
            left = "move-column-left";
            down = "move-window-down";
            up = "move-window-up";
            right = "move-column-right";
          })

          (mkDirectionalBinds "Mod+Shift" {
            left = "focus-monitor-left";
            down = "focus-monitor-down";
            up = "focus-monitor-up";
            right = "focus-monitor-right";
          })

          (mkDirectionalBinds "Mod+Shift+Ctrl" {
            left = "move-column-to-monitor-left";
            down = "move-column-to-monitor-down";
            up = "move-column-to-monitor-up";
            right = "move-column-to-monitor-right";
          })

          (mkScrollBinds "Mod" {
            left = "focus-column-left";
            right = "focus-column-right";
            up = "focus-workspace-up";
            down = "focus-workspace-down";
          })

          (mkScrollBinds "Mod+Ctrl" {
            left = "move-column-left";
            right = "move-column-right";
            up = "move-column-to-workspace-up";
            down = "move-column-to-workspace-down";
          })

          (mkWorkspaceNumberBinds "Mod" "focus-workspace")
          (mkWorkspaceNumberBinds "Mod+Shift" "move-column-to-workspace")
        ];
      };
  };
}
