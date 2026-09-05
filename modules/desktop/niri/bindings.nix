{ config, lib, ... }:
{
  config = lib.mkIf config.desktop.niri.enable {
    home.extraOptions =
      let
        noArg = action: { action.${action} = [ ]; };
        withArg = action: value: { action.${action} = value; };
        spawn = command: { action.spawn = command; };
        # set-window-width only touches width, which is fine for a tiled
        # column but leaves a float looking stretched instead of scaled — so
        # on a float, grow/shrink height by the same step too. niri anchors
        # a resize at the top-left corner, which would drift the float off
        # whatever position it was at, so shift it back by half the pixel
        # delta on both axes to resize symmetrically in place.
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

        # --- the grammar ------------------------------------------------
        #
        # Every navigation bind is generated, never hand-listed, so the
        # grammar cannot drift out of sync with itself. One modifier, one
        # meaning:
        #
        #   Mod        act on / focus the thing
        #   Mod+Shift  move the focused thing
        #   Mod+Ctrl   act one scope up (the monitor, or the workspace itself)
        #   Mod+Alt    move without following (focus=false)
        #
        # See ./KEYBINDINGS.md for the full table and the two places the
        # grammar deliberately bends.

        # Physical keys that mean each logical direction. Arrows and hjkl are
        # always bound to the same action — no plane binds one without the
        # other.
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

        # The workspace axis is vertical and separate from the direction keys
        # above: up/down here move between workspaces, not between windows.
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

        # Bind one modifier plane over a key family. `args` is passed to every
        # action in the plane — that is how the Alt plane gets `focus=false`
        # without a second helper. Directions absent from `actions` stay
        # unbound, which is how the Alt direction plane binds only left/right.
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

        # Wheel binds follow the same grammar: Mod focuses, Mod+Shift moves.
        # Vertical scroll crosses workspaces and needs a cooldown or one flick
        # of the wheel walks several workspaces.
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

        # The Alt plane's whole point: niri takes `focus=false` as a property
        # on every move-to-workspace action, so the same action that follows
        # the window on Shift stays put on Alt.
        stay = [ { focus = false; } ];
      in
      {
        programs.niri.settings.binds = lib.mkMerge [
          {
            # --- launcher and shell surfaces ---------------------------
            # omarchy-style root menu (dankMenu plugin, see ../dms/plugins.nix):
            # one key to every command, with its own search and app list. This
            # replaces DMS's spotlight as the general launcher — spotlight is
            # still reachable for its trigger-based plugins, see Mod+Alt+E.
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
            "Mod+N" = spawn (dms [
              "notifications"
              "toggle"
            ]);
            # D is the dashboard family: the dash itself, then the two other
            # full-screen system surfaces as its variants.
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

            # --- scratchpad --------------------------------------------
            # scratchpad (argosnothing/niri-scratchpad-rs). `create 1` toggles
            # register 1: it stashes the focused window to the "stash"
            # workspace and shows it back as a float, so the one bind both
            # minimises and restores. --as-float so the shown scratchpad
            # floats over its workspace.
            "Mod+M" = spawn [
              "niri-scratchpad"
              "create"
              "1"
              "--as-float"
            ];

            # --- session -----------------------------------------------
            # BackSpace is the session family: lock, lock+suspend, power menu,
            # and monitors-off, in rising order of how much they turn off.
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
            "Mod+Alt+BackSpace" = noArg "power-off-monitors";
            "Mod+Escape" = {
              allow-inhibiting = false;
              action.toggle-keyboard-shortcuts-inhibit = [ ];
            };
            # The only bind that quits niri. There used to be a Mod+Shift+E as
            # well, one Shift away from Mod+E (the file manager) — deleted.
            "Ctrl+Alt+Delete" = noArg "quit";

            # --- media / volume ----------------------------------------
            # wpctl (wireplumber), not pactl: this system has no
            # pulseaudio-utils installed at all, so every pactl invocation
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
            # F11's icon on this keyboard (blank/unlabeled) — raw scancode
            # confirmed via evtest as KEY_PROG2 -> XF86Launch2.
            "XF86Launch2" = spawn (dms [
              "virtualKeyboard"
              "toggle"
            ]);

            # --- apps ---------------------------------------------------
            # Plain Mod+letter for the three apps opened by reflex. Everything
            # else that merely *runs* something lives on the Mod+Alt plane
            # below, so Mod+Shift and Mod+Ctrl are never a launcher.
            "Mod+T" = {
              hotkey-overlay.title = "Open a terminal";
              action.spawn = "ghostty";
            };
            "Mod+B" = spawn "helium";
            "Mod+E" = spawn "nautilus";

            # --- Mod+Alt+<letter>: run a tool ---------------------------
            # The tool plane. Alt on a letter always means "run this thing";
            # Alt on a nav key always means "move without following". The two
            # never collide because they use different key classes.
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
            "Mod+Alt+W" = spawn (dms [
              "dankdash"
              "wallpaper"
            ]);
            "Mod+Alt+N" = spawn (dms [
              "night"
              "toggle"
            ]);
            # emoji / unicode picker (emojiLauncher plugin, trigger ":e"): open
            # spotlight pre-filled with the trigger so it lands straight on the
            # emoji search. Trailing space is intentional (starts the filter).
            "Mod+Alt+E" = spawn (dms [
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

            # --- window ops ---------------------------------------------
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
            # W is the floating family: float it, cross to the other layer,
            # pin it above every workspace. Floating in needs its own nice
            # size and position — niri keeps whatever size/place the window
            # last had, which after a fresh toggle is usually its tiled
            # column size in the corner — so only on tiled->float do we set
            # a size and center; float->tiled leaves the tiling layout alone.
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

            # column consume/expel. Un-stack with these before a Shift/Alt
            # move if you want a single window on the target workspace — every
            # move bind acts on the whole column.
            "Mod+BracketLeft" = noArg "consume-or-expel-window-left";
            "Mod+BracketRight" = noArg "consume-or-expel-window-right";
            "Mod+Comma" = noArg "consume-window-into-column";
            "Mod+Period" = noArg "expel-window-from-column";

            # --- screen capture ------------------------------------------
            # S is the capture family. The bare Print key keeps niri's own
            # built-in screenshot UI; Mod+S opens a region capture in DMS's
            # quickCapture annotation editor, and the two variants are the
            # grim pipelines that bypass any editor.
            #
            # `edit` is quickCapture's action argument: it opens the shot in
            # the annotator. `float` is the other one — the shot becomes an
            # always-on-top window with no editor — and there is no keybind
            # for it because the editor's Ctrl+F does the same thing once the
            # shot is up.
            #
            # The Print binds below only fire from an external keyboard. The
            # omnibook's internal keyboard has no Print keycode: the key
            # printed with the scissors icon is a Windows "snip" key and emits
            # Super+Shift+S in firmware, which lands on Mod+Shift+S here. That
            # happens to be the region-to-clipboard bind, so the key does the
            # right thing by accident -- do not "fix" it by moving Mod+Shift+S.
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

            # --- workspace nav that has no family -------------------------
            # Home/End used to focus and move a column to the first/last
            # position. Unused in practice, so they are gone rather than
            # sitting in the cheat sheet as noise.
            "Mod+Tab" = noArg "focus-workspace-previous";
          }

          # --- direction keys: arrows and hjkl ----------------------------
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

          # Alt on the direction keys has no "without following" meaning —
          # every target is on screen already — so the horizontal half is
          # spent on swapping instead. Up/down stay unbound.
          (mkBinds directionKeys "Mod+Alt" [ ] {
            left = "swap-window-left";
            right = "swap-window-right";
          })

          # --- workspace axis: U/I and Page_Up/Page_Down -------------------
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

          # The one bend in the grammar: on this axis plain Mod is already the
          # scope-up (the workspace), so Ctrl reorders the workspace itself
          # instead of reaching for the monitor.
          (mkBinds workspaceKeys "Mod+Ctrl" [ ] {
            up = "move-workspace-up";
            down = "move-workspace-down";
          })

          # --- wheel -------------------------------------------------------
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

          # --- number row --------------------------------------------------
          (mkNumberBinds "Mod" [ ] "focus-workspace")
          (mkNumberBinds "Mod+Shift" [ ] "move-column-to-workspace")
          (mkNumberBinds "Mod+Alt" stay "move-column-to-workspace")
          (mkNumberBinds "Mod+Ctrl" [ ] "move-workspace-to-index")
        ];
      };
  };
}
