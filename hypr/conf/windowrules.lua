-- Window rules for DMS windows (copied from DMS into kaerice).

-- DMS-RULE: id=dms-floating-windows, name=DMS Floating Windows
hl.window_rule({ match = { class = "^(dev\\.duxlabs\\.shell|com\\.danklinux\\.dms)$" }, float = true })

-- DMS-RULE: id=dms-window-opaque, name=DMS Window Opaque
hl.window_rule({ match = { class = "^(dev\\.duxlabs\\.shell|com\\.danklinux\\.dms)$" }, opaque = true })
