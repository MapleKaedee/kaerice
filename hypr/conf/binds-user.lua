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
