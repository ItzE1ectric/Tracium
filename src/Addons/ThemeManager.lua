--[[==========================================================================]]
-- Tracium v2 · Addons/ThemeManager.lua
-- Obsidian/Linoria-style theme manager. Builds a control group on any tab or
-- window settings surface.
--
--   local ThemeManager = Tracium.Addons.ThemeManager
--   ThemeManager:SetLibrary(Tracium)
--   ThemeManager:ApplyToTab(settingsTab)
--   ThemeManager:SetTheme("Violet")
--[[==========================================================================]]

return function(Shared)
	local TM = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme

	TM.Library = nil
	TM.AppliedTheme = Theme.Current

	function TM:SetLibrary(lib)
		TM.Library = lib
		return TM
	end

	function TM:SetTheme(name)
		if Theme:Palette(name) then
			Theme:Set(name)
			TM.AppliedTheme = name
			if TM.Library then
				Shared.Config:NotifyChange("__theme", name)
			end
			return true
		end
		return false
	end

	function TM:GetThemeNames()
		return Theme:Names()
	end

	function TM:NextTheme()
		local names = Theme:Names()
		local idx = table.find(names, Theme.Current) or 1
		local next_ = names[(idx % #names) + 1]
		TM:SetTheme(next_)
		return next_
	end

	-- Full control group
	function TM:ApplyToTab(host)
		local ThemeCtl = host.CreateSection and host:CreateSection("Theme", { Icon = "palette" }) or host

		ThemeCtl:Dropdown({
			Title = "Preset",
			Values = Theme:Names(),
			Default = Theme.Current,
			Flag = "TraciumTheme",
			Callback = function(name)
				TM:SetTheme(name)
			end,
			Tooltip = "Pick a color palette",
		})

		ThemeCtl:Button({
			Title = "Cycle theme",
			Chip = "Next",
			Callback = function()
				local next_ = TM:NextTheme()
				if TM.Library then
					TM.Library:Notify({ Title = "Theme", Content = next_, Duration = 2 })
				end
			end,
		})

		-- Custom accent pair -> registers a custom theme from scratch colors
		ThemeCtl:ColorPicker({
			Title = "Accent color",
			Flag = "TraciumCustomAccent",
			Default = Theme:Get("Accent"),
			Callback = function(c)
				Theme:RegisterCustom("Custom", { Accent = c, Glow = c })
				Theme:Set("Custom")
			end,
			Tooltip = "Builds a custom theme around this accent",
		})
		ThemeCtl:ColorPicker({
			Title = "Secondary accent",
			Flag = "TraciumCustomAccent2",
			Default = Theme:Get("Accent2"),
			Callback = function(c)
				local cur = Theme:Palette("Custom") or Theme:Palette(Theme.Current)
				Theme:RegisterCustom("Custom", { Accent = cur and cur.Accent, Accent2 = c })
				Theme:Set("Custom")
			end,
		})

		return ThemeCtl
	end

	return TM
end
