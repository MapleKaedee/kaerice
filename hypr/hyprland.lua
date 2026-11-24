-- Hyprland configuration (Lua) — https://wiki.hypr.land/configuring/

-- session env + systemd target (formerly the DMS_STARTUP block)
hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	if not os.getenv("HYPRLAND_NO_SD_TARGET") then
		hl.exec_cmd("systemctl --user start hyprland-session.target")
	end
end)

-- touchpad off while an external mouse is plugged (Hyprland has no native option)
hl.on("hyprland.start", function()
	hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/touchpad-auto.sh")
end)

-- kaerice: own Quickshell shell (~/Projects/kaerice). DMS is skipped on Hyprland
-- via ~/.config/systemd/user/dms.service.d/skip-hyprland.conf
hl.on("hyprland.start", function()
	-- run binary directly: the systemd unit needs WAYLAND_DISPLAY imported first (races with the session env block above)
	hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
	hl.exec_cmd("qs -c kaerice")
end)

hl.config({
	input = {
		-- empty inherits XKB_DEFAULT_LAYOUT (libxkbcommon), falls back to "us"
		kb_layout = "",
		numlock_by_default = true,
		follow_mouse = 1, -- focus follows hover (like niri/mango)
		-- conf/input.lua is required later and wins per key
		touchpad = {
			tap_to_click = true,
			natural_scroll = true,
		},
	},
	general = {
		gaps_in = 5,
		gaps_out = 5,
		border_size = 2,
		layout = "scrolling",
	},
	decoration = {
		rounding = 12,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = {
			enabled = true,
			range = 30,
			render_power = 4,
			offset = "0 5",
			color = "rgba(00000070)",
		},
	},
	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		-- kaerice lock: if Quickshell crashes while locked, its restart may take the lock back
		allow_session_lock_restore = true,
	},
	dwindle = {
		preserve_split = true,
	},
	master = {
		mfact = 0.5,
	},
	binds = {
		-- let focus left/right leave a maximized/fullscreen window (default only jumps monitors)
		movefocus_cycles_fullscreen = true,
	},
	scrolling = {
		column_width = 0.5,
		explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
		focus_fit_method = 1, -- 0 center, 1 fit, 2 clamped_center
	},
})

hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "default" })

hl.window_rule({ match = { class = "^(org\\.wezfurlong\\.wezterm)$" }, tile = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.)" }, rounding = 12 })
hl.window_rule({ match = { class = "^(gnome-control-center)$" }, tile = true })
hl.window_rule({ match = { class = "^(pavucontrol)$" }, tile = true })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, tile = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.Calculator)$" }, float = true })
hl.window_rule({ match = { class = "^(gnome-calculator)$" }, float = true })
hl.window_rule({ match = { class = "^(galculator)$" }, float = true })
hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true })
hl.window_rule({ match = { class = "^(xdg-desktop-portal)$" }, float = true })
hl.window_rule({
	match = { class = "^(steam)$", title = "^(notificationtoasts)" },
	no_initial_focus = true,
	pin = true,
})
hl.window_rule({
	match = { class = "^(firefox)$", title = "^(Picture-in-Picture)$" },
	float = true,
})
hl.window_rule({ match = { class = "^(zoom)$" }, float = true })
hl.layer_rule({ match = { namespace = "^(quickshell)$" }, no_anim = true })

require("conf.colors")
require("conf.outputs")
require("conf.layout")
require("conf.cursor")
require("conf.input")
require("conf.binds")
require("conf.binds-user")

-- osu! lazer: tearing for lowest latency.
-- No direct_scanout: in hybrid MUX mode it froze the screen (NVIDIA buffer can't be imported to AMD KMS);
-- in dGPU mode it got stuck on sync flips (Draw capped at 144, dim colors, frozen frame after osu closed).
hl.config({ general = { allow_tearing = true } })
hl.window_rule({ match = { class = "^(osu!)$" }, immediate = true })
