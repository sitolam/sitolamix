{ lib, ... }:
{
  flake.modules.homeManager.shared =
    { ... }:
    let
      noArg = action: { action.${action} = [ ]; };
      withArg = action: value: { action.${action} = value; };
      spawn = command: { action.spawn = command; };
      noctalia = command: [ "noctalia" "ipc" "call" ] ++ command;

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
          # noctalia panels
          "Mod+Space" = spawn (noctalia [ "launcher" "toggle" ]);
          "Mod+Ctrl+Return" = spawn (noctalia [ "launcher" "toggle" ]);
          "Mod+V" = spawn (noctalia [ "launcher" "clipboard" ]);
          "Mod+Shift+Period" = spawn (noctalia [ "launcher" "emoji" ]);
          "Mod+Return" = spawn (noctalia [ "plugin:assistant-panel" "toggle" ]);
          "Mod+Slash" = spawn (noctalia [ "plugin:keybind-cheatsheet" "toggle" ]);
          "Mod+S" = spawn (noctalia [ "controlCenter" "toggle" ]);
          "Mod+N" = spawn (noctalia [ "notifications" "toggle" ]);

          # session
          "Mod+BackSpace" = spawn (noctalia [ "lockScreen" "lock" ]);
          "Mod+Shift+BackSpace" = spawn (noctalia [ "sessionMenu" "lockAndSuspend" ]);
          "Mod+Ctrl+BackSpace" = spawn (noctalia [ "sessionMenu" "toggle" ]);

          # theme control
          "Mod+Shift+T" = spawn "switch-theme";
          "Mod+Shift+W" = spawn (noctalia [ "plugin:theme-picker" "toggle" ]);

          # media / volume
          "XF86AudioRaiseVolume" = spawn [ "pactl" "set-sink-volume" "@DEFAULT_SINK@" "+5%" ];
          "XF86AudioLowerVolume" = spawn [ "pactl" "set-sink-volume" "@DEFAULT_SINK@" "-5%" ];
          "XF86AudioMute" = spawn [ "pactl" "set-sink-mute" "@DEFAULT_SINK@" "toggle" ];
          "XF86AudioPlay" = spawn [ "playerctl" "play-pause" ];
          "XF86AudioNext" = spawn [ "playerctl" "next" ];
          "XF86AudioPrev" = spawn [ "playerctl" "previous" ];
          "XF86MonBrightnessUp" = spawn [ "brightnessctl" "set" "5%+" ];
          "XF86MonBrightnessDown" = spawn [ "brightnessctl" "set" "5%-" ];

          # apps
          "Mod+T" = {
            hotkey-overlay.title = "Open a terminal";
            action.spawn = "ghostty";
          };
          "Mod+B" = spawn "helium";
          "Mod+E" = spawn "nautilus";
          "Mod+Shift+G" = spawn [ "ghostty" "-e" "lazygit" ];
          "Mod+Shift+M" = spawn [ "ghostty" "-e" "btop" ];

          # window ops
          "Mod+Q" = noArg "close-window";
          "Mod+O" = { repeat = false; action.toggle-overview = [ ]; };
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
          "Mod+Ctrl+Space" = spawn [ "nsticky" "sticky" "toggle-active" ];

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
          "Mod+Shift+S" = { action.screenshot = [ ]; };
          "Ctrl+Print" = noArg "screenshot-screen";
          "Alt+Print" = noArg "screenshot-window";
          "Print" = noArg "screenshot";

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
}
