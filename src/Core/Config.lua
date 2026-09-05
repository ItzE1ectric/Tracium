--[[==========================================================================]]
-- Tracium v2 · Core/Config.lua
-- Flag registry + JSON config persistence with multiple profiles.
--
-- How flags flow:
--   * Each element calls Config:Register(flag, element) at creation.
--   * Element must expose :Get() and a silent, callback-free :Set().
--   * Config keeps Config.Flags[flag] = latest value (plain Lua values).
--   * When a config is loaded, stored values are stashed in
--     Config.Pending; new elements consume pending values for their flag
--     and existing elements get :Set() applied immediately.
--
--   * Elements call Config:NotifyChange(flag, value) on every user change
--     (ScheduleSave handles the debounce; nothing auto-writes unless an
--     autoload profile is active or the window opted into auto-save).
--
-- Executor FS (writefile/readfile/listfiles...) is used when available;
-- otherwise the system silently degrades to in-memory profiles so the API
-- keeps working in Studio / restricted environments.
--[[==========================================================================]]

return function(Shared)
	local Config = {}

	local Utility = Shared.Utility
	local Signal = Shared.Signal
	local Http = Shared.Services.HttpService

	----------------------------------------------------------------------
	-- State
	----------------------------------------------------------------------

	Config.Folder = "Tracium"            -- root folder (created if FS present)
	Config.ActiveProfile = nil           -- current profile name (string) or nil
	Config.Flags = {}                    -- flag -> current value (decoded)
	Config.Elements = {}                 -- flag -> element
	Config.Pending = {}                  -- flag -> decoded value waiting to be consumed
	Config.Autosave = true               -- write automatically after changes
	Config.AutosaveDelay = 0.5           -- debounce (seconds)
	Config.IgnoreEmpty = true            -- do not write configs that have no flags

	Config.ProfileLoaded = Signal.new()  -- (name)
	Config.ProfileSaved = Signal.new()   -- (name)
	Config.ProfileDeleted = Signal.new() -- (name)
	Config.Changed = Signal.new()        -- (flag, value)

	local _saveToken = 0

	----------------------------------------------------------------------
	-- Paths
	----------------------------------------------------------------------

	local function RootFolder()
		return Config.Folder
	end

	local function ProfilesFolder()
		return RootFolder() .. "/profiles"
	end

	local function ProfilePath(name)
		return ProfilesFolder() .. "/" .. name .. ".json"
	end

	local function SanitizeName(name)
		name = tostring(name or "default")
		-- keep it file-name friendly
		name = name:gsub('[%c%z<>:"/\\|%?%*]', "_")
		name = Utility.Trim(name)
		if #name == 0 then
			name = "default"
		end
		if #name > 48 then
			name = name:sub(1, 48)
		end
		return name
	end
	Config.SanitizeName = SanitizeName

	local function EnsureTree()
		Utility.FS.EnsureFolder(RootFolder())
		Utility.FS.EnsureFolder(ProfilesFolder())
	end

	----------------------------------------------------------------------
	-- Element registration
	----------------------------------------------------------------------

	-- Returns true if a pending value existed (and was consumed).
	function Config:Register(element)
		local flag = element.Flag
		if not flag then
			return false
		end
		if Config.Elements[flag] and Config.Elements[flag] ~= element then
			-- duplicate flag: last writer wins, but warn loudly in output
			warn(("[Tracium] Duplicate flag registered: %s (element %s replaced by %s)")
				:format(flag, tostring(Config.Elements[flag].Type), tostring(element.Type)))
		end
		Config.Elements[flag] = element

		local pending = Config.Pending[flag]
		if pending ~= nil then
			Config.Pending[flag] = nil
			local ok, err = pcall(function()
				if element.ConfigSet then
					element:ConfigSet(pending)
				else
					element:Set(pending)
				end
			end)
			if not ok then
				warn(("[Tracium] Failed applying pending value for flag %q: %s"):format(flag, tostring(err)))
			end
			return true
		end

		-- no pending: snapshot the default into Flags so first save is complete
		if element.Get then
			local ok, value = pcall(function()
				return element:Get()
			end)
			if ok then
				Config.Flags[flag] = value
			end
		end
		return false
	end

	function Config:Unregister(flag)
		Config.Elements[flag] = nil
		Config.Flags[flag] = nil
	end

	-- Called by elements whenever their value changes (user-driven or :Set).
	function Config:NotifyChange(flag, value)
		if not flag then
			return
		end
		Config.Flags[flag] = value
		Config.Changed:Fire(flag, value)
		if Shared.Library then
			Shared.Library.Flags[flag] = value
		end
		Config:ScheduleSave()
	end

	----------------------------------------------------------------------
	-- Save
	----------------------------------------------------------------------

	function Config:Collect()
		local payload = {
			__tracium = 2,
			profile = Config.ActiveProfile,
			savedAt = os.time(),
			flags = {},
		}
		for flag, value in pairs(Config.Flags) do
			if value ~= nil then
				payload.flags[flag] = Utility.EncodeValue(value)
			end
		end
		return payload
	end

	function Config:Save(name)
		name = SanitizeName(name or Config.ActiveProfile or "default")
		Config.ActiveProfile = name

		if not Utility.FS.Available then
			Config._memory = Config._memory or {}
			Config._memory[name] = Config:Collect()
			Config.ProfileSaved:Fire(name)
			return true, "memory"
		end

		local okEncode, json = pcall(function()
			return Http:JSONEncode(Config:Collect())
		end)
		if not okEncode then
			return false, "encode failed"
		end
		EnsureTree()
		local ok = Utility.FS.Write(ProfilePath(name), json)
		if ok then
			Config.ProfileSaved:Fire(name)
			return true, ProfilePath(name)
		end
		return false, "write failed"
	end

	-- Debounced auto-save; called on every flag change.
	function Config:ScheduleSave()
		if not Config.Autosave then
			return
		end
		_saveToken += 1
		local token = _saveToken
		task.delay(Config.AutosaveDelay, function()
			if token ~= _saveToken then
				return -- superseded by a newer change
			end
			if Config.ActiveProfile then
				Config:Save(Config.ActiveProfile)
			end
		end)
	end

	----------------------------------------------------------------------
	-- Load
	----------------------------------------------------------------------

	local function ApplyData(data)
		if type(data) ~= "table" or type(data.flags) ~= "table" then
			return 0
		end
		local applied = 0
		for flag, encoded in pairs(data.flags) do
			local value = Utility.DecodeValue(encoded)
			Config.Flags[flag] = value
			if Shared.Library then
				Shared.Library.Flags[flag] = value
			end
			local element = Config.Elements[flag]
			if element then
				local ok, err = pcall(function()
					if element.ConfigSet then
						element:ConfigSet(value)
					else
						element:Set(value)
					end
				end)
				if not ok then
					warn(("[Tracium] Failed applying config value for flag %q: %s"):format(flag, tostring(err)))
				else
					applied += 1
				end
			else
				-- element not created yet: stash for Register() to consume
				Config.Pending[flag] = value
				applied += 1
			end
		end
		return applied
	end

	function Config:Load(name)
		name = SanitizeName(name or Config.ActiveProfile or "default")
		local data

		if Utility.FS.Available then
			local raw = Utility.FS.Read(ProfilePath(name))
			if not raw then
				return false, "not found"
			end
			local ok, decoded = pcall(function()
				return Http:JSONDecode(raw)
			end)
			if not ok or type(decoded) ~= "table" then
				return false, "decode failed"
			end
			data = decoded
		else
			data = Config._memory and Config._memory[name]
			if not data then
				return false, "not found"
			end
		end

		Config.ActiveProfile = name
		local applied = ApplyData(data)
		Config.ProfileLoaded:Fire(name)
		return true, applied
	end

	function Config:Delete(name)
		name = SanitizeName(name)
		if Config.ActiveProfile == name then
			Config.ActiveProfile = nil
		end
		if Config._memory then
			Config._memory[name] = nil
		end
		if Utility.FS.Available then
			local ok = Utility.FS.Delete(ProfilePath(name))
			Config.ProfileDeleted:Fire(name)
			return ok
		end
		Config.ProfileDeleted:Fire(name)
		return true
	end

	function Config:Rename(old, new)
		old, new = SanitizeName(old), SanitizeName(new)
		if old == new then
			return false, "same name"
		end
		local ok, payload = self:Load(old)
		if not ok then
			return false, payload
		end
		self:Save(new)
		self:Delete(old)
		self.ActiveProfile = new
		return true
	end

	----------------------------------------------------------------------
	-- Listing profiles
	----------------------------------------------------------------------

	function Config:List()
		local names = {}
		local seen = {}
		if Utility.FS.Available then
			EnsureTree()
			for _, path in ipairs(Utility.FS.List(ProfilesFolder())) do
				local name = path:match("([^/\\]+)%.json$")
				if name and not seen[name] then
					seen[name] = true
					table.insert(names, name)
				end
			end
		end
		if Config._memory then
			for name in pairs(Config._memory) do
				if not seen[name] then
					seen[name] = true
					table.insert(names, name)
				end
			end
		end
		table.sort(names)
		return names
	end

	function Config:Exists(name)
		name = SanitizeName(name)
		if Utility.FS.Available and Utility.FS.Exists(ProfilePath(name)) then
			return true
		end
		return Config._memory ~= nil and Config._memory[name] ~= nil
	end

	----------------------------------------------------------------------
	-- Autoload marker ("load this profile next session automatically")
	----------------------------------------------------------------------

	local function AutoloadPath()
		return RootFolder() .. "/_autoload.json"
	end

	function Config:SetAutoload(name)
		if not Utility.FS.Available then
			Config._autoload = name
			return true
		end
		EnsureTree()
		if name == nil or name == false then
			Utility.FS.Delete(AutoloadPath())
			return true
		end
		local ok, json = pcall(function()
			return Http:JSONEncode({ profile = SanitizeName(name) })
		end)
		if not ok then
			return false
		end
		return Utility.FS.Write(AutoloadPath(), json)
	end

	function Config:GetAutoload()
		if not Utility.FS.Available then
			return Config._autoload
		end
		local raw = Utility.FS.Read(AutoloadPath())
		if not raw then
			return nil
		end
		local ok, data = pcall(function()
			return Http:JSONDecode(raw)
		end)
		if ok and type(data) == "table" then
			return data.profile
		end
		return nil
	end

	----------------------------------------------------------------------
	-- Reset current in-memory flags to element defaults
	----------------------------------------------------------------------

	function Config:ResetToDefaults()
		for flag, element in pairs(Config.Elements) do
			local default = element.Default
			if default ~= nil then
				pcall(function()
					if element.ConfigSet then
						element:ConfigSet(Utility.DeepCopy(default))
					else
						element:Set(Utility.DeepCopy(default))
					end
				end)
				Config.Flags[flag] = element.Default
			end
		end
		Config.Changed:Fire("*", nil)
	end

	----------------------------------------------------------------------
	-- Serialization convenience used by addons / settings tab
	----------------------------------------------------------------------

	function Config:Export()
		local ok, json = pcall(function()
			return Http:JSONEncode(Config:Collect())
		end)
		return ok and json or nil
	end

	function Config:Import(json)
		local ok, data = pcall(function()
			return Http:JSONDecode(json)
		end)
		if not ok or type(data) ~= "table" then
			return false, "invalid json"
		end
		local applied = ApplyData(data)
		Config:ScheduleSave()
		return true, applied
	end

	return Config
end
