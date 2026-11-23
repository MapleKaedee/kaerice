-- Colors copied from DMS (matugen output) into kaerice; edit freely.

hl.config({
	general = {
		col = {
			active_border = "rgb(ffffff)",
			inactive_border = "rgb(333333)",
		},
	},
	group = {
		col = {
			border_active = "rgb(ffffff)",
			border_inactive = "rgb(333333)",
			border_locked_active = "rgb(ff6b6b)",
			border_locked_inactive = "rgb(333333)",
		},
		groupbar = {
			col = {
				active = "rgb(ffffff)",
				inactive = "rgb(333333)",
				locked_active = "rgb(ff6b6b)",
				locked_inactive = "rgb(333333)",
			},
		},
	},
})

-- Effect colors exist only on newer Hyprland; skip them elsewhere instead of raising config errors
local function themed(key, value)
	local ok, current = pcall(hl.get_config, key)
	if ok and current ~= nil then
		hl.config({ [key] = value })
	end
end

themed("decoration.glow.color", "rgba(ffffffee)")
themed("decoration.glow.color_inactive", "rgba(333333ee)")
themed("decoration.blur.acrylic.tint", "rgba(ffffff14)")
themed("decoration.blur.aurora.color1", "rgba(ffffff29)")
themed("decoration.blur.aurora.color2", "rgba(a3a3a37a)")
themed("decoration.blur.fluid_jar.color", "rgba(ffffffcc)")
