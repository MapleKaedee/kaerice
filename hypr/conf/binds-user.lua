-- Your keybinds (copied from DMS into kaerice).
-- Loaded after binds.lua: binding a stock key here replaces it, hl.unbind("SUPER + X") frees it.

hl.unbind("SUPER + R")
hl.bind("SUPER + R", hl.dsp.layout("colresize +conf"))
hl.unbind("SUPER + period")
hl.bind("SUPER + period", hl.dsp.layout("move +col"))
hl.unbind("SUPER + bracketleft")
hl.bind("SUPER + bracketleft", hl.dsp.layout("consume_or_expel prev"))
hl.unbind("SUPER + bracketright")
hl.bind("SUPER + bracketright", hl.dsp.layout("consume_or_expel next"))

-- kaerice shell (Quickshell IPC)
hl.bind("SUPER + space", hl.dsp.exec_cmd("qs -c kaerice ipc call launcher toggle"))
hl.bind("SUPER + X", hl.dsp.exec_cmd("qs -c kaerice ipc call power toggle"))
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("qs -c kaerice ipc call power toggle"))
hl.bind("SUPER + Y", hl.dsp.exec_cmd("qs -c kaerice ipc call wallpaper pick"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("qs -c kaerice ipc call notifications toggle"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("qs -c kaerice ipc call clipboard toggle"))
hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd("qs -c kaerice ipc call lock lock"))
-- Alt+Tab switcher: global shortcuts (ordered, no process per press); releasing Alt switches
hl.bind("ALT + Tab", hl.dsp.global("quickshell:switcherNext"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.global("quickshell:switcherPrev"))
