-- DMS default keybinds (Hyprland 0.55+ Lua)
-- Copied from DMS into kaerice; edit freely. binds-user.lua loads after this and overrides it.

-- === Application Launchers ===
hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"), { description = "Apps: terminal" })
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"), { description = "Apps: terminal" })

-- === Audio Controls ===
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("qs -c kaerice ipc call osd volumeUp"), { locked = true, repeating = true, description = "Audio: volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("qs -c kaerice ipc call osd volumeDown"), { locked = true, repeating = true, description = "Audio: volume down" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("qs -c kaerice ipc call osd toggleMute"), { locked = true, description = "Audio: mute" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, description = "Audio: mute microphone" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("qs -c kaerice ipc call media playPause"), { locked = true, description = "Media: play / pause" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("qs -c kaerice ipc call media playPause"), { locked = true, description = "Media: play / pause" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("qs -c kaerice ipc call media previous"), { locked = true, description = "Media: previous" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("qs -c kaerice ipc call media next"), { locked = true, description = "Media: next" })
hl.bind("CTRL + XF86AudioRaiseVolume", hl.dsp.exec_cmd("qs -c kaerice ipc call media volumeUp"), { locked = true, repeating = true, description = "Media: player volume up" })
hl.bind("CTRL + XF86AudioLowerVolume", hl.dsp.exec_cmd("qs -c kaerice ipc call media volumeDown"), { locked = true, repeating = true, description = "Media: player volume down" })

-- === Brightness Controls ===
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("qs -c kaerice ipc call osd brightnessUp"), { locked = true, repeating = true, description = "Display: brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs -c kaerice ipc call osd brightnessDown"), { locked = true, repeating = true, description = "Display: brightness down" })

-- === Window Management ===
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Window: close" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Window: maximize" })
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Window: fullscreen" })
hl.bind("SUPER + SHIFT + T", hl.dsp.window.float({ action = "toggle" }), { description = "Window: float / tile" })
hl.bind("SUPER + W", hl.dsp.group.toggle(), { description = "Window: toggle group" })

-- === Focus Navigation ===
hl.bind("SUPER + left", hl.dsp.focus({ direction = "l" }), { description = "Focus: left" })
hl.bind("SUPER + down", hl.dsp.focus({ direction = "d" }), { description = "Focus: down" })
hl.bind("SUPER + up", hl.dsp.focus({ direction = "u" }), { description = "Focus: up" })
hl.bind("SUPER + right", hl.dsp.focus({ direction = "r" }), { description = "Focus: right" })
hl.bind("SUPER + H", hl.dsp.focus({ direction = "l" }), { description = "Focus: left" })
hl.bind("SUPER + J", hl.dsp.focus({ direction = "d" }), { description = "Focus: down" })
hl.bind("SUPER + K", hl.dsp.focus({ direction = "u" }), { description = "Focus: up" })
hl.bind("SUPER + L", hl.dsp.focus({ direction = "r" }), { description = "Focus: right" })

-- === Window Movement ===
hl.bind("SUPER + SHIFT + left", hl.dsp.window.move({ direction = "l" }), { description = "Window: move left" })
hl.bind("SUPER + SHIFT + down", hl.dsp.window.move({ direction = "d" }), { description = "Window: move down" })
hl.bind("SUPER + SHIFT + up", hl.dsp.window.move({ direction = "u" }), { description = "Window: move up" })
hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "r" }), { description = "Window: move right" })
hl.bind("SUPER + SHIFT + H", hl.dsp.window.move({ direction = "l" }), { description = "Window: move left" })
hl.bind("SUPER + SHIFT + J", hl.dsp.window.move({ direction = "d" }), { description = "Window: move down" })
hl.bind("SUPER + SHIFT + K", hl.dsp.window.move({ direction = "u" }), { description = "Window: move up" })
hl.bind("SUPER + SHIFT + L", hl.dsp.window.move({ direction = "r" }), { description = "Window: move right" })

-- === Column Navigation ===
hl.bind("SUPER + Home", hl.dsp.focus({ window = "first" }), { description = "Focus: first column" })
hl.bind("SUPER + End", hl.dsp.focus({ window = "last" }), { description = "Focus: last column" })

-- === Monitor Navigation ===
hl.bind("SUPER + CTRL + left", hl.dsp.focus({ monitor = "l" }), { description = "Monitor: focus left" })
hl.bind("SUPER + CTRL + right", hl.dsp.focus({ monitor = "r" }), { description = "Monitor: focus right" })
hl.bind("SUPER + CTRL + H", hl.dsp.focus({ monitor = "l" }), { description = "Monitor: focus left" })
hl.bind("SUPER + CTRL + J", hl.dsp.focus({ monitor = "d" }), { description = "Monitor: focus down" })
hl.bind("SUPER + CTRL + K", hl.dsp.focus({ monitor = "u" }), { description = "Monitor: focus up" })
hl.bind("SUPER + CTRL + L", hl.dsp.focus({ monitor = "r" }), { description = "Monitor: focus right" })

-- === Move to Monitor ===
hl.bind("SUPER + SHIFT + CTRL + left", hl.dsp.window.move({ monitor = "l" }), { description = "Monitor: move window left" })
hl.bind("SUPER + SHIFT + CTRL + down", hl.dsp.window.move({ monitor = "d" }), { description = "Monitor: move window down" })
hl.bind("SUPER + SHIFT + CTRL + up", hl.dsp.window.move({ monitor = "u" }), { description = "Monitor: move window up" })
hl.bind("SUPER + SHIFT + CTRL + right", hl.dsp.window.move({ monitor = "r" }), { description = "Monitor: move window right" })
hl.bind("SUPER + SHIFT + CTRL + H", hl.dsp.window.move({ monitor = "l" }), { description = "Monitor: move window left" })
hl.bind("SUPER + SHIFT + CTRL + J", hl.dsp.window.move({ monitor = "d" }), { description = "Monitor: move window down" })
hl.bind("SUPER + SHIFT + CTRL + K", hl.dsp.window.move({ monitor = "u" }), { description = "Monitor: move window up" })
hl.bind("SUPER + SHIFT + CTRL + L", hl.dsp.window.move({ monitor = "r" }), { description = "Monitor: move window right" })

-- === Workspace Navigation ===
hl.bind("SUPER + Page_Down", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspace: next" })
hl.bind("SUPER + Page_Up", hl.dsp.focus({ workspace = "e-1" }), { description = "Workspace: previous" })
hl.bind("SUPER + U", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspace: next" })
hl.bind("SUPER + I", hl.dsp.focus({ workspace = "e-1" }), { description = "Workspace: previous" })
hl.bind("SUPER + CTRL + down", hl.dsp.window.move({ workspace = "e+1" }), { description = "Workspace: move window to next" })
hl.bind("SUPER + CTRL + up", hl.dsp.window.move({ workspace = "e-1" }), { description = "Workspace: move window to previous" })
hl.bind("SUPER + CTRL + U", hl.dsp.window.move({ workspace = "e+1" }), { description = "Workspace: move window to next" })
hl.bind("SUPER + CTRL + I", hl.dsp.window.move({ workspace = "e-1" }), { description = "Workspace: move window to previous" })

-- === Workspace Management ===

-- === Scratchpad ===
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special(), { description = "Scratchpad: show / hide" })
hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special", follow = false }), { description = "Scratchpad: send window" })
hl.bind("SUPER + CTRL + S", hl.dsp.window.move({ workspace = "+0" }), { description = "Scratchpad: bring window back" })

-- === Move Workspaces ===
hl.bind("SUPER + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "e+1" }), { description = "Workspace: move window to next" })
hl.bind("SUPER + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "e-1" }), { description = "Workspace: move window to previous" })
hl.bind("SUPER + SHIFT + U", hl.dsp.window.move({ workspace = "e+1" }), { description = "Workspace: move window to next" })
hl.bind("SUPER + SHIFT + I", hl.dsp.window.move({ workspace = "e-1" }), { description = "Workspace: move window to previous" })

-- === Mouse Wheel Navigation ===
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspace: next" })
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Workspace: previous" })
hl.bind("SUPER + CTRL + mouse_down", hl.dsp.window.move({ workspace = "e+1" }), { description = "Workspace: move window to next" })
hl.bind("SUPER + CTRL + mouse_up", hl.dsp.window.move({ workspace = "e-1" }), { description = "Workspace: move window to previous" })

-- === Touchpad Gestures ===
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- === Numbered Workspaces ===
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = "1" }), { description = "Workspace: go to 1" })
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = "2" }), { description = "Workspace: go to 2" })
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = "3" }), { description = "Workspace: go to 3" })
hl.bind("SUPER + 4", hl.dsp.focus({ workspace = "4" }), { description = "Workspace: go to 4" })
hl.bind("SUPER + 5", hl.dsp.focus({ workspace = "5" }), { description = "Workspace: go to 5" })
hl.bind("SUPER + 6", hl.dsp.focus({ workspace = "6" }), { description = "Workspace: go to 6" })
hl.bind("SUPER + 7", hl.dsp.focus({ workspace = "7" }), { description = "Workspace: go to 7" })
hl.bind("SUPER + 8", hl.dsp.focus({ workspace = "8" }), { description = "Workspace: go to 8" })
hl.bind("SUPER + 9", hl.dsp.focus({ workspace = "9" }), { description = "Workspace: go to 9" })

-- === Move to Numbered Workspaces ===
hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = "1" }), { description = "Workspace: move window to 1" })
hl.bind("SUPER + SHIFT + 2", hl.dsp.window.move({ workspace = "2" }), { description = "Workspace: move window to 2" })
hl.bind("SUPER + SHIFT + 3", hl.dsp.window.move({ workspace = "3" }), { description = "Workspace: move window to 3" })
hl.bind("SUPER + SHIFT + 4", hl.dsp.window.move({ workspace = "4" }), { description = "Workspace: move window to 4" })
hl.bind("SUPER + SHIFT + 5", hl.dsp.window.move({ workspace = "5" }), { description = "Workspace: move window to 5" })
hl.bind("SUPER + SHIFT + 6", hl.dsp.window.move({ workspace = "6" }), { description = "Workspace: move window to 6" })
hl.bind("SUPER + SHIFT + 7", hl.dsp.window.move({ workspace = "7" }), { description = "Workspace: move window to 7" })
hl.bind("SUPER + SHIFT + 8", hl.dsp.window.move({ workspace = "8" }), { description = "Workspace: move window to 8" })
hl.bind("SUPER + SHIFT + 9", hl.dsp.window.move({ workspace = "9" }), { description = "Workspace: move window to 9" })

-- === Column Management ===
hl.bind("SUPER + bracketleft", hl.dsp.layout("preselect l"), { description = "Layout: consume / expel left" })
hl.bind("SUPER + bracketright", hl.dsp.layout("preselect r"), { description = "Layout: consume / expel right" })

-- === Sizing & Layout ===
hl.bind("SUPER + R", hl.dsp.layout("togglesplit"), { description = "Layout: cycle column width" })
hl.bind("SUPER + CTRL + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "set" }), { description = "Window: maximize (keep)" })

-- === Move/resize windows with mainMod + LMB/RMB and dragging ===
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: move with mouse" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Window: resize with mouse" })

-- === Manual Sizing ===
hl.bind("SUPER + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true, description = "Window: narrower" })
hl.bind("SUPER + equal", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { repeating = true, description = "Window: wider" })
hl.bind("SUPER + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true, description = "Window: shorter" })
hl.bind("SUPER + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { repeating = true, description = "Window: taller" })

-- === Screenshots ===
-- each capture opens in the kaerice editor; without the shell it goes straight to ~/Pictures/Screenshots + clipboard
local shot = os.getenv("HOME") .. "/.config/quickshell/kaerice/scripts/screenshot.sh "
hl.bind("Print", hl.dsp.exec_cmd(shot .. "region"), { description = "Screenshot: region" })
hl.bind("CTRL + Print", hl.dsp.exec_cmd(shot .. "screen"), { description = "Screenshot: screen" })
hl.bind("ALT + Print", hl.dsp.exec_cmd(shot .. "window"), { description = "Screenshot: window" })

-- === System Controls ===
hl.bind("SUPER + SHIFT + P", hl.dsp.dpms({ action = "toggle" }), { description = "Display: screen on / off" })
