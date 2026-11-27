-- Your keybinds (copied from DMS into kaerice).
-- Loaded after binds.lua: binding a stock key here replaces it, hl.unbind("SUPER + X") frees it.

hl.unbind("SUPER + R")
hl.bind("SUPER + R", hl.dsp.layout("colresize +conf"), { description = "Layout: cycle column width" })
hl.unbind("SUPER + period")
hl.bind("SUPER + period", hl.dsp.layout("move +col"), { description = "Layout: move window to next column" })
hl.unbind("SUPER + bracketleft")
hl.bind("SUPER + bracketleft", hl.dsp.layout("consume_or_expel prev"), { description = "Layout: consume / expel left" })
hl.unbind("SUPER + bracketright")
hl.bind("SUPER + bracketright", hl.dsp.layout("consume_or_expel next"), { description = "Layout: consume / expel right" })

-- kaerice shell (Quickshell IPC)
hl.bind("SUPER + space", hl.dsp.exec_cmd("qs -c kaerice ipc call launcher toggle"), { description = "Shell: launcher" })
hl.bind("SUPER + X", hl.dsp.exec_cmd("qs -c kaerice ipc call power toggle"), { description = "Shell: power menu" })
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("qs -c kaerice ipc call power toggle"), { description = "Shell: power menu" })
hl.bind("SUPER + Y", hl.dsp.exec_cmd("qs -c kaerice ipc call wallpaper pick"), { description = "Shell: wallpaper picker" })
hl.bind("SUPER + N", hl.dsp.exec_cmd("qs -c kaerice ipc call notifications toggle"), { description = "Shell: notifications" })
hl.bind("SUPER + V", hl.dsp.exec_cmd("qs -c kaerice ipc call clipboard toggle"), { description = "Shell: clipboard history" })
hl.bind("SUPER + semicolon", hl.dsp.exec_cmd("qs -c kaerice ipc call emoji toggle"), { description = "Shell: emoji picker" })
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("qs -c kaerice ipc call note toggle"), { description = "Shell: temp note" })
hl.bind("SUPER + D", hl.dsp.exec_cmd("qs -c kaerice ipc call dashboard toggle"), { description = "Shell: dashboard" })
hl.bind("SUPER + A", hl.dsp.exec_cmd("qs -c kaerice ipc call controlCenter toggle"), { description = "Shell: control center" })
hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd("qs -c kaerice ipc call lock lock"), { description = "Shell: lock screen" })
-- Alt+Tab switcher: global shortcuts (ordered, no process per press); releasing Alt switches
hl.bind("ALT + Tab", hl.dsp.global("quickshell:switcherNext"), { description = "Shell: switch window" })
hl.bind("ALT + SHIFT + Tab", hl.dsp.global("quickshell:switcherPrev"), { description = "Shell: switch window back" })
-- here, not in the switcher: after a quick Alt+Tab, Alt is up before its window has keyboard focus.
-- transparent: else ALT + Tab shadows it and it never fires after a Tab
hl.bind("Alt_L", hl.dsp.global("quickshell:switcherCommit"), { release = true, non_consuming = true, transparent = true, ignore_mods = true, description = "Shell: switch window on Alt release" })
hl.bind("Alt_R", hl.dsp.global("quickshell:switcherCommit"), { release = true, non_consuming = true, transparent = true, ignore_mods = true, description = "Shell: switch window on Alt release" })
hl.bind("SUPER + Tab", hl.dsp.exec_cmd("qs -c kaerice ipc call switcher overview"), { description = "Shell: overview" })
hl.bind("SUPER + comma", hl.dsp.exec_cmd("qs -c kaerice ipc call settings toggle"), { description = "Shell: settings" })
hl.bind("SUPER + slash", hl.dsp.exec_cmd("qs -c kaerice ipc call keybinds toggle"), { description = "Shell: keybind cheat sheet" })
-- Caps / Num Lock popup: on release (the state settles there), with any modifier, never swallowing the key
hl.bind("Caps_Lock", hl.dsp.exec_cmd("qs -c kaerice ipc call osd capsLock"), { release = true, non_consuming = true, ignore_mods = true, locked = true, description = "Display: Caps Lock popup" })
hl.bind("Num_Lock", hl.dsp.exec_cmd("qs -c kaerice ipc call osd numLock"), { release = true, non_consuming = true, ignore_mods = true, locked = true, description = "Display: Num Lock popup" })
