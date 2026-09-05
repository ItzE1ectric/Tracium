--[[==========================================================================]]
-- Tracium v2 · Init.lua
-- Entry module: builds Shared, loads every module in dependency order, and
-- returns the public `Tracium` table.
--
-- Boot contexts supported:
--   1. Bundled single file  (built by build.ps1; modules are preloaded into
--      a constructor table injected as `__TRACIUM_CONSTRUCTORS` upvalue)
--   2. Studio playground    (each src/*.lua pasted as sibling ModuleScripts
--      is NOT required; the single file is the supported distribution)
--
-- When not bundled, `Shared.FetchModule(name)` may be assigned by the loader
-- wrapper to resolve module source (e.g. via game:HttpGet from a repo).
--[[==========================================================================]]

local function Bootstrap(constructors)
	local Shared = {}
	Shared.Version = "2.0.0"

	-- -- services ------------------------------------------------------
	local function svc(name)
		return game:GetService(name)
	end

	local function cloneRef(obj)
		local ok, cloned = pcall(function()
			return cloneref(obj)
		end)
		return (ok and cloned) or obj
	end

	local Services = {
		TweenService = svc("TweenService"),
		UserInputService = svc("UserInputService"),
		RunService = svc("RunService"),
		HttpService = svc("HttpService"),
		Lighting = svc("Lighting"),
		Players = svc("Players"),
		TextService = svc("TextService"),
		GuiService = svc("GuiService"),
		CoreGui = svc("CoreGui"),
		Workspace = svc("Workspace"),
		Stats = svc("Stats"),
	}
	for k, v in pairs(Services) do
		Services[k] = cloneRef(v)
	end
	Services.LocalPlayer = Services.Players.LocalPlayer
	Shared.Services = Services

	-- -- module loader ---------------------------------------------------
	local cache = {}
	local fetchOverride = nil

	function Shared.RegisterFetcher(fn)
		fetchOverride = fn
	end

	function Shared.Load(name)
		if cache[name] ~= nil then
			return cache[name]
		end
		local ctor = constructors and constructors[name]
		if ctor == nil and fetchOverride then
			local src = fetchOverride(name)
			if src then
				local chunk, err = loadstring(src)
				if not chunk then
					error(("[Tracium] failed to compile module %s: %s"):format(name, tostring(err)))
				end
				ctor = chunk()
			end
		end
		assert(ctor ~= nil, ("[Tracium] module %q is not bundled and no fetcher is registered"):format(name))
		-- constructor-style modules are functions called with Shared;
		-- data modules (e.g. Core.IconMap) return their value directly.
		local mod
		if type(ctor) == "function" then
			mod = ctor(Shared)
		else
			mod = ctor
		end
		-- constructor may itself return a constructor (wrapped data); accept both
		if type(mod) == "function" and name:match("IconMap") then
			mod = mod(Shared)
		end
		cache[name] = mod
		return mod
	end
	Shared.Define = Shared.Load

	-- Core first (order matters: later modules read these from Shared)
	Shared.Utility = Shared.Load("Core.Utility")
	Shared.Signal = Shared.Load("Core.Signal")
	Shared.Tween = Shared.Load("Core.Tween")
	Shared.Theme = Shared.Load("Core.Theme") -- Theme before Tooltip: Tooltip captures it at chunk time
	Shared.Icons = Shared.Load("Core.Icons")
	Shared.Drag = Shared.Load("Core.Drag")
	Shared.Acrylic = Shared.Load("Core.Acrylic")
	Shared.Tooltip = Shared.Load("Core.Tooltip")
	Shared.Notify = Shared.Load("Core.Notify")
	Shared.Config = Shared.Load("Core.Config")

	-- Components
	Shared.Components = {}
	for _, name in ipairs({
		"Button", "Toggle", "Slider", "Dropdown", "ColorPicker", "Keybind",
		"Input", "Label", "Paragraph", "Divider", "ProgressBar", "Image", "Dialog",
	}) do
		Shared.Components[name] = Shared.Load("Components." .. name)
	end

	-- Containers. Section exports the element Factory + Section + GroupBox;
	-- Tab destructures Factory at chunk time, so Section must load first and
	-- expose it through Shared.Containers before Tab runs.
	Shared.Containers = {}
	local sectionMod = Shared.Load("Containers.Section")
	Shared.Containers.Section = sectionMod.Section
	Shared.Containers.GroupBox = sectionMod.GroupBox
	Shared.Containers.Factory = sectionMod.Factory
	Shared.Containers.Tab = Shared.Load("Containers.Tab")
	Shared.Containers.Window = Shared.Load("Containers.Window")

	-- Optional addons (loaded on demand; failure must never kill the lib)
	Shared.Addons = {}
	for _, name in ipairs({ "ThemeManager", "SaveManager", "KeybindList" }) do
		local ok, mod = pcall(Shared.Load, "Addons." .. name)
		if ok then
			Shared.Addons[name] = mod
		end
	end

	----------------------------------------------------------------------
	-- Public library table
	----------------------------------------------------------------------

	local Tracium = {
		Version = Shared.Version,
		Flags = {},          -- global flag -> value mirror (Config pushes here)
		Windows = {},        -- all live windows
		Shared = Shared,     -- escape hatch for addons / power users
	}
	Shared.Library = Tracium

	-- -- window management -----------------------------------------------

	function Tracium:CreateWindow(opts)
		local window = Shared.Containers.Window.New(Shared, opts or {})
		table.insert(self.Windows, window)
		return window
	end

	-- v1 alias
	Tracium.Create = Tracium.CreateWindow

	function Tracium:DestroyAll()
		for _, w in ipairs(self.Windows) do
			pcall(function()
				w:Destroy()
			end)
		end
		table.clear(self.Windows)
	end

	function Tracium:Notify(opts)
		return Shared.Notify:Push(opts)
	end

	-- -- theme passthrough -------------------------------------------------

	function Tracium:SetTheme(name)
		Shared.Theme:Set(name)
	end

	function Tracium:GetTheme()
		return Shared.Theme.Current
	end

	function Tracium:ThemeNames()
		return Shared.Theme:Names()
	end

	-- -- utility passthroughs ------------------------------------------------

	function Tracium:Icon(name, size, color)
		return Shared.Icons:Create(name, size, color)
	end

	function Tracium:Unload()
		self:DestroyAll()
		Shared.Notify:ClearAll()
		if Shared.Acrylic and Shared.Acrylic.Disable then
			Shared.Acrylic:Disable()
		end
	end

	return Tracium
end

-- Module form: Init is itself a module whose constructor receives the
-- bundled constructors table (nil when a fetch-override loader is used).
return function(constructors)
	return Bootstrap(constructors)
end
