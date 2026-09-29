{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.niri.enable {
    home.extraOptions =
      let
        noArg = action: { action.${action} = [ ]; };
        withArg = action: value: { action.${action} = value; };
        spawn = command: { action.spawn = command; };
        # set-window-width only touches width, so on a float also resize
        # height by the same step. niri anchors resizes at the top-left, so
        # shift the float back by half the pixel delta to stay centered.
        mkFloatAwareResize =
          pct:
          spawn [
            "sh"
            "-c"
            ''
              before=$(niri msg -j focused-window)
              niri msg action set-window-width ${pct}
              if [ "$(echo "$before" | jq -r .is_floating)" = "true" ]; then
                niri msg action set-window-height ${pct}
                before_w=$(echo "$before" | jq -r '.layout.window_size[0]')
                before_h=$(echo "$before" | jq -r '.layout.window_size[1]')
                after=$(niri msg -j focused-window)
                after_w=$(echo "$after" | jq -r '.layout.window_size[0]')
                after_h=$(echo "$after" | jq -r '.layout.window_size[1]')
                # move-floating-window's -x/-y use the same +/- convention
                # as set-window-width: a signless number is an absolute
                # position, not a delta. printf forces the sign so a
                # non-negative shift still moves relatively instead of
                # jumping the window to that literal coordinate.
                niri msg action move-floating-window \
                  -x "$(printf '%+d' $(( (before_w - after_w) / 2 )))" \
                  -y "$(printf '%+d' $(( (before_h - after_h) / 2 )))"
              fi
            ''
          ];
        dms =
          command:
          [
            "dms"
            "ipc"
            "call"
          ]
          ++ command;

        # Grammar (every nav bind is generated, never hand-listed): Mod acts
        # on/focuses; Mod+Shift moves; Mod+Ctrl acts one scope up (monitor or
        # workspace); Mod+Alt moves without following. Full table and the
        # two exceptions: ./KEYBINDINGS.md.

        # Arrows and hjkl are always bound to the same action.
        directionKeys = {
          left = [
            "Left"
            "H"
          ];
          down = [
            "Down"
            "J"
          ];
          up = [
            "Up"
            "K"
          ];
          right = [
            "Right"
            "L"
          ];
        };

        # Separate from directionKeys: up/down here move between workspaces.
        workspaceKeys = {
          up = [
            "U"
            "Page_Up"
          ];
          down = [
            "I"
            "Page_Down"
          ];
        };

        # Bind one modifier plane over a key family; `args` is passed to
        # every action (how Alt gets focus=false without a second helper).
        mkBinds =
          keys: modifier: args: actions:
          builtins.listToAttrs (
            lib.concatLists (
              lib.mapAttrsToList (
                direction: action:
                map (key: lib.nameValuePair "${modifier}+${key}" { action.${action} = args; }) keys.${direction}
              ) actions
            )
          );

        # Mod+1..9 plus Mod+0 for workspace 10.
        mkNumberBinds =
          modifier: args: action:
          builtins.listToAttrs (
            map (
              workspace:
              lib.nameValuePair "${modifier}+${toString (lib.mod workspace 10)}" {
                action.${action} = args ++ [ workspace ];
              }
            ) (lib.range 1 10)
          );

        # Vertical scroll crosses workspaces and needs a cooldown, or one
        # flick walks several workspaces.
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

        # focus=false: the same action that follows on Shift stays put on Alt.
        stay = [ { focus = false; } ];
      in
      {
        programs.niri.settings.binds = lib.mkMerge [
          {
            # dankMenu replaces DMS's spotlight as the general launcher;
            # spotlight is still reachable for its trigger plugins (Mod+Alt+E).
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
            "Mod+N" = spawn (dms [
              "notifications"
              "toggle"
            ]);
            # dash plus its two full-screen variants.
            "Mod+D" = spawn (dms [
              "dash"
              "toggle"
            ]);
            "Mod+Shift+D" = spawn (dms [
              "processlist"
              "toggle"
            ]);
            "Mod+Ctrl+D" = spawn (dms [
              "control-center"
              "toggle"
            ]);

            # `create 1` toggles register 1: stashes the focused window to a
            # "stash" workspace, or restores it as a float — one bind both
            # minimises and restores.
            "Mod+M" = spawn [
              "niri-scratchpad"
              "create"
              "1"
              "--as-float"
            ];

            # lock / lock+suspend / power menu / monitors-off, rising order
            # of how much they turn off.
            "Mod+BackSpace" = spawn (dms [
              "lock"
              "lock"
            ]);
            # locks explicitly first so we never flash the desktop before
            # swayidle's own before-sleep lock.
            "Mod+Shift+BackSpace" = spawn [
              "sh"
              "-c"
              "loginctl lock-session && systemctl suspend"
            ];
            "Mod+Ctrl+BackSpace" = spawn (dms [
              "powermenu"
              "toggle"
            ]);
            "Mod+Alt+BackSpace" = noArg "power-off-monitors";
            "Mod+Escape" = {
              allow-inhibiting = false;
              action.toggle-keyboard-shortcuts-inhibit = [ ];
            };
            # The only bind that quits niri.
            "Ctrl+Alt+Delete" = noArg "quit";

            # wpctl, not pactl: no pulseaudio-utils is installed, so pactl
            # would silently fail (127).
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
            # F9's mic-mute icon; scancode confirmed via evtest as KEY_MICMUTE.
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
            # internal panel plus both external monitors — DMS has no "all"
            # DDC target. ddc:i2c-5 = HDMI-A-1, ddc:i2c-6 = DP-3; update if
            # the i2c bus numbers shift (ddcutil detect). The trailing "" is
            # required: dms ipc enforces the handler's full arity.
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
            # F11's blank icon; evtest confirms KEY_PROG2 -> XF86Launch2.
            "XF86Launch2" = spawn (dms [
              "virtualKeyboard"
              "toggle"
            ]);

            # Plain Mod+letter for the three apps opened by reflex; anything
            # that merely runs something else lives on Mod+Alt below.
            "Mod+T" = {
              hotkey-overlay.title = "Open a terminal";
              action.spawn = "ghostty";
            };
            "Mod+B" = spawn "helium";
            "Mod+E" = spawn "nautilus";

            # Mod+Alt+<letter>: Alt on a letter means "run this thing"; Alt
            # on a nav key means "move without following" — different key classes.
            "Mod+Alt+G" = spawn [
              "ghostty"
              "-e"
              "lazygit"
            ];
            "Mod+Alt+M" = spawn [
              "ghostty"
              "-e"
              "btop"
            ];
            "Mod+Alt+S" = spawn [
              "sh"
              "-c"
              "hyprpicker -a"
            ];
            "Mod+Alt+T" = spawn (dms [
              "theme"
              "toggle"
            ]);
            # wallpaperCarousel, not dankdash's own grid: browses the whole
            # folder full-screen. dankdash's picker is one row away in dankMenu.
            "Mod+Alt+W" = spawn (dms [
              "wallpaperCarousel"
              "toggle"
            ]);
            "Mod+Alt+N" = spawn (dms [
              "night"
              "toggle"
            ]);
            # emoji picker: opens spotlight pre-filled on the ":e" trigger.
            # Trailing space is intentional (starts the filter).
            "Mod+Alt+E" = spawn (dms [
              "spotlight"
              "toggleQuery"
              ":e "
            ]);
            # F2 is a plain literal key (evtest: KEY_F2), bound as Mod+F2 to
            # avoid shadowing bare F2 in apps that bind it directly.
            "Mod+F2" = spawn (dms [
              "spotlight"
              "toggleQuery"
              ":e "
            ]);

            "Mod+Q" = noArg "close-window";
            "Mod+O" = {
              repeat = false;
              action.toggle-overview = [ ];
            };
            "Mod+A" = noArg "toggle-column-tabbed-display";
            "Mod+R" = noArg "switch-preset-column-width";
            "Mod+Shift+R" = noArg "switch-preset-window-height";
            "Mod+Ctrl+R" = noArg "reset-window-height";
            "Mod+F" = noArg "maximize-column";
            "Mod+Shift+F" = noArg "fullscreen-window";
            "Mod+Ctrl+F" = noArg "expand-column-to-available-width";
            "Mod+C" = noArg "center-column";
            "Mod+Ctrl+C" = noArg "center-visible-columns";
            "Mod+Minus" = mkFloatAwareResize "-10%";
            "Mod+Equal" = mkFloatAwareResize "+10%";
            "Mod+Shift+Minus" = withArg "set-window-height" "-10%";
            "Mod+Shift+Equal" = withArg "set-window-height" "+10%";
            # Floating-in needs its own size/position — niri keeps whatever
            # the window last had, usually its tiled corner size — so only
            # tiled->float sets a size and centers.
            "Mod+W" = spawn [
              "sh"
              "-c"
              ''
                was_floating=$(niri msg -j focused-window | jq -r .is_floating)
                niri msg action toggle-window-floating
                if [ "$was_floating" = "false" ]; then
                  niri msg action set-window-width 55%
                  niri msg action set-window-height 65%
                  niri msg action center-window
                fi
              ''
            ];
            "Mod+Shift+W" = noArg "switch-focus-between-floating-and-tiling";
            "Mod+Ctrl+W" = spawn [
              "nsticky"
              "sticky"
              "toggle-active"
            ];

            # Un-stack with these before a Shift/Alt move — move binds
            # otherwise act on the whole column.
            "Mod+BracketLeft" = noArg "consume-or-expel-window-left";
            "Mod+BracketRight" = noArg "consume-or-expel-window-right";
            "Mod+Comma" = noArg "consume-window-into-column";
            "Mod+Period" = noArg "expel-window-from-column";

            # Bare Print keeps niri's built-in screenshot UI; Mod+S opens
            # quickCapture's annotation editor; the other variants are grim
            # pipelines that bypass any editor. The Print binds only fire
            # from an external keyboard — the omnibook's "snip" key emits
            # Super+Shift+S in firmware and lands on Mod+Shift+S by accident;
            # don't "fix" it by moving that bind.
            "Mod+S" = spawn (dms [
              "quickCapture"
              "screenshot"
              "region"
              "edit"
            ]);
            "Mod+Shift+S" = spawn [
              "sh"
              "-c"
              "grim -g \"$(slurp)\" - | wl-copy"
            ];
            "Mod+Ctrl+S" = spawn [
              "sh"
              "-c"
              "grim -g \"$(slurp)\" - | tesseract - - | wl-copy"
            ];
            "Print" = noArg "screenshot";
            "Ctrl+Print" = noArg "screenshot-screen";
            "Alt+Print" = noArg "screenshot-window";
            "Mod+Print" = spawn [
              "sh"
              "-c"
              "grim -g \"$(slurp)\" - | wl-copy"
            ];

            "Mod+Tab" = noArg "focus-workspace-previous";
          }

          (mkBinds directionKeys "Mod" [ ] {
            left = "focus-column-left";
            down = "focus-window-down";
            up = "focus-window-up";
            right = "focus-column-right";
          })

          (mkBinds directionKeys "Mod+Shift" [ ] {
            left = "move-column-left";
            down = "move-window-down";
            up = "move-window-up";
            right = "move-column-right";
          })

          (mkBinds directionKeys "Mod+Ctrl" [ ] {
            left = "focus-monitor-left";
            down = "focus-monitor-down";
            up = "focus-monitor-up";
            right = "focus-monitor-right";
          })

          (mkBinds directionKeys "Mod+Ctrl+Shift" [ ] {
            left = "move-column-to-monitor-left";
            down = "move-column-to-monitor-down";
            up = "move-column-to-monitor-up";
            right = "move-column-to-monitor-right";
          })

          # Alt has no "without following" meaning here, so it's spent on
          # swapping instead. Up/down stay unbound.
          (mkBinds directionKeys "Mod+Alt" [ ] {
            left = "swap-window-left";
            right = "swap-window-right";
          })

          (mkBinds workspaceKeys "Mod" [ ] {
            up = "focus-workspace-up";
            down = "focus-workspace-down";
          })

          (mkBinds workspaceKeys "Mod+Shift" [ ] {
            up = "move-column-to-workspace-up";
            down = "move-column-to-workspace-down";
          })

          (mkBinds workspaceKeys "Mod+Alt" stay {
            up = "move-column-to-workspace-up";
            down = "move-column-to-workspace-down";
          })

          # The bend: plain Mod is already scope-up here, so Ctrl reorders
          # the workspace itself instead of reaching for the monitor.
          (mkBinds workspaceKeys "Mod+Ctrl" [ ] {
            up = "move-workspace-up";
            down = "move-workspace-down";
          })

          (mkScrollBinds "Mod" {
            left = "focus-column-left";
            right = "focus-column-right";
            up = "focus-workspace-up";
            down = "focus-workspace-down";
          })

          (mkScrollBinds "Mod+Shift" {
            left = "move-column-left";
            right = "move-column-right";
            up = "move-column-to-workspace-up";
            down = "move-column-to-workspace-down";
          })

          (mkNumberBinds "Mod" [ ] "focus-workspace")
          (mkNumberBinds "Mod+Shift" [ ] "move-column-to-workspace")
          (mkNumberBinds "Mod+Alt" stay "move-column-to-workspace")
          (mkNumberBinds "Mod+Ctrl" [ ] "move-workspace-to-index")
        ];
      };
  };
}
