--[[==========================================================================]]
-- Tracium v2 · Addons/SaveManager.lua
-- Config profile management controls (dropdown + save/load/delete/reset).
--
--   local SaveManager = Tracium.Addons.SaveManager
--   SaveManager:SetLibrary(Tracium)
--   SaveManager:SetFolder("Tracium/MyScript")
--   SaveManager:ApplyToTab(settingsTab)
--[[==========================================================================]]

return function(Shared)
	local SM = {}
	local Config = Shared.Config
	local Utility = Shared.Utility

	SM.Library = nil

	function SM:SetLibrary(lib)
		SM.Library = lib
		return SM
	end

	function SM:SetFolder(folder)
		Config.Folder = folder or "Tracium"
		return SM
	end

	function SM:SetProfile(name)
		Config.ActiveProfile = Config.SanitizeName(name)
		return SM
	end

	-- Build controls on a tab/section
	function SM:ApplyToTab(host)
		local grp = host.CreateSection and host:CreateSection("Configuration", { Icon = "save" }) or host
		local dropdown

		local function refreshList()
			if dropdown then
				dropdown:Refresh(Config:List(), true)
			end
		end

		dropdown = grp:Dropdown({
			Title = "Profile",
			Values = Config:List(),
			Default = Config.ActiveProfile,
			Placeholder = "Select profile",
			Callback = function(name)
				if type(name) == "string" and name ~= "" then
					Config:Load(name)
				end
			end,
			Tooltip = "Switch config profile",
		})

		local nameInput = grp:Input({
			Title = "Profile name",
			Placeholder = "e.g. main",
			Callback = function() end,
		})

		grp:Button({
			Title = "Save",
			Chip = "Write",
			Callback = function()
				local name = nameInput:Get()
				if name == "" then
					name = Config.ActiveProfile or "default"
				end
				Config:Save(name)
				refreshList()
				if SM.Library then
					SM.Library:Notify({ Title = "Config", Content = "Saved profile '" .. name .. "'", Type = "Success", Duration = 2 })
				end
			end,
		})

		grp:Button({
			Title = "Load",
			Callback = function()
				local name = nameInput:Get() ~= "" and nameInput:Get() or Config.ActiveProfile
				if not name then
					return
				end
				local ok, res = Config:Load(name)
				if SM.Library then
					if ok then
						SM.Library:Notify({ Title = "Config", Content = "Loaded '" .. name .. "' (" .. tostring(res) .. " options)", Type = "Success", Duration = 2 })
					else
						SM.Library:Notify({ Title = "Config", Content = "Load failed: " .. tostring(res), Type = "Error", Duration = 3 })
					end
				end
			end,
		})

		grp:Button({
			Title = "Delete profile",
			Variant = "Danger",
			HoldToConfirm = true,
			Callback = function()
				local name = nameInput:Get() ~= "" and nameInput:Get() or Config.ActiveProfile
				if not name then
					return
				end
				Config:Delete(name)
				refreshList()
			end,
		})

		grp:Button({
			Title = "Reset to defaults",
			Variant = "Danger",
			HoldToConfirm = true,
			Callback = function()
				Config:ResetToDefaults()
				if SM.Library then
					SM.Library:Notify({ Title = "Config", Content = "All options reset", Type = "Warning", Duration = 2 })
				end
			end,
		})

		grp:Toggle({
			Title = "Auto-load profile",
			Flag = "__autoload",
			Default = false,
			Callback = function(v)
				if v and Config.ActiveProfile then
					Config:SetAutoload(Config.ActiveProfile)
				elseif not v then
					Config:SetAutoload(nil)
				end
			end,
		})

		Config.ProfileSaved:Connect(function()
			refreshList()
		end)
		Config.ProfileDeleted:Connect(function()
			refreshList()
		end)

		return grp
	end

	return SM
end
