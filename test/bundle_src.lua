-- gen
return [====[--[===========================================================================[
	Tracium v2 â€” bundled single-file distribution (auto-generated)
	Built by build.ps1 â€” do not edit; edit src/*.lua then rebuild.
	Loads with: loadstring(...)()
]===========================================================================]

local __MODULES = {}

--===========================[ Core.Signal ]===========================--
__MODULES["Core.Signal"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Core/Signal.lua
-- Lightweight, dependency-free signal/event implementation.
-- API is compatible with the classic "Quenty-lite" style signals:
--   local sig = Signal.new()
--   local conn = sig:Connect(function(a, b) ... end)
--   sig:Fire(1, 2)           -- fires all handlers in spawned threads
--   sig:FireSync(1, 2)       -- fires inline (errors propagate to caller)
--   local a, b = sig:Wait()  -- yields until next Fire
--   conn:Disconnect()
--   sig:Destroy()
--[[==========================================================================]]

return function(Shared)
	local Signal = {}
	Signal.__index = Signal

	local Connection = {}
	Connection.__index = Connection

	function Connection.new(signal, fn)
		return setmetatable({
			Connected = true,
			_signal = signal,
			_fn = fn,
		}, Connection)
	end

	function Connection:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		local handlers = self._signal._handlers
		for i, conn in ipairs(handlers) do
			if conn == self then
				table.remove(handlers, i)
				break
			end
		end
		if self._once then
			self._signal = nil
		end
	end

	function Signal.new()
		return setmetatable({
			_handlers = {},
			_bound = false,
		}, Signal)
	end

	function Signal:IsSignal()
		return true
	end

	function Signal:Connect(fn)
		assert(type(fn) == "function", "Signal:Connect expects a function")
		local conn = Connection.new(self, fn)
		table.insert(self._handlers, conn)
		return conn
	end

	function Signal:Once(fn)
		local conn
		conn = self:Connect(function(...)
			conn:Disconnect()
			fn(...)
		end)
		conn._once = true
		return conn
	end

	function Signal:Fire(...)
		-- Snapshot: a handler disconnecting or connecting during Fire
		-- must not corrupt the iteration.
		local handlers = self._handlers
		local snapshot = table.create(#handlers)
		for i, conn in ipairs(handlers) do
			snapshot[i] = conn
		end
		for _, conn in ipairs(snapshot) do
			if conn.Connected then
				task.spawn(conn._fn, ...)
			end
		end
	end

	function Signal:FireSync(...)
		local snapshot = table.create(#self._handlers)
		for i, conn in ipairs(self._handlers) do
			snapshot[i] = conn
		end
		for _, conn in ipairs(snapshot) do
			if conn.Connected then
				conn._fn(...)
			end
		end
	end

	function Signal:Wait()
		local thread = coroutine.running()
		local conn
		conn = self:Connect(function(...)
			conn:Disconnect()
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end

	function Signal:DisconnectAll()
		for _, conn in ipairs(self._handlers) do
			conn.Connected = false
		end
		table.clear(self._handlers)
	end

	function Signal:Destroy()
		self:DisconnectAll()
		setmetatable(self, nil)
	end

	function Signal:Count()
		return #self._handlers
	end

	return Signal
end

end)()

--===========================[ Core.Utility ]===========================--
__MODULES["Core.Utility"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Core/Utility.lua
-- Instance factory + glue helpers used by every other module.
--
-- ============================ MODULE CONTRACT ==============================
-- Every file under src/ is a module of the form:
--
--     return function(Shared)   -- constructor, called once by the loader
--         local M = {}
--         ...
--         return M
--     end
--
-- No requires between modules: everything flows through `Shared`.
-- The loader (src/Init.lua) populates these keys before use:
--
--   Shared.Version            string
--   Shared.Services           {TweenService, UserInputService, RunService,
--                              HttpService, Lighting, Players, TextService,
--                              GuiService, CoreGui, Workspace, LocalPlayer}
--   Shared.Utility  Shared.Signal  Shared.Tween   Shared.Icons
--   Shared.Drag     Shared.Acrylic Shared.Tooltip Shared.Theme
--   Shared.Config   Shared.Notify  Shared.Dialog
--   Shared.Components  = {}   -- Components.X after each is loaded
--   Shared.Containers  = {}
--   Shared.Library    = set by Init (the public Tracium table)
--
-- Component contract (every file under src/Components):
--   local Element = {}
--   function Element.New(scope, opts) -> handle
--     scope = {
--       Window   = window object,     -- Window.Raw, :UnregisterKeybind(kb) etc.
--       Page     = GuiObject,         -- parent container for element root
--       Index    = number,            -- element count for layout ordering
--       Section  = section|nil,
--     }
--   handle.Root  (GuiObject, the outermost frame; Window sets Search attr)
--   handle.Type, handle.Value, handle.Flag, handle.Options
--   handle:Set(...) / handle:Get()
--   handle:Destroy()
--     (optional) handle.Visible(bool), handle:SetTooltip(text),
--                handle:ConfigGet(), handle:ConfigSet(value)
--
-- Colour access convention: Utility.Paint(inst, "Prop", "ThemeKey") for static
-- colours (auto re-painted on theme switch) or Shared.Theme:Get("Key") when a
-- one-off read is needed. Never hardcode palette colors in components; accent
-- overlays use Theme:Get("Accent") etc.
--==========================================================================]]

return function(Shared)
	local Utility = {}

	local Services = Shared.Services

	----------------------------------------------------------------------
	-- Instance plumbing
	----------------------------------------------------------------------

	-- Utility.New("Frame", { Size = ..., Parent = ... }) -> Instance
	-- Properties assigned in an undefined order EXCEPT Parent, which is last.
	function Utility.New(class, props, children)
		local inst = Instance.new(class)
		for k, v in pairs(props or {}) do
			if k ~= "Parent" then
				inst[k] = v
			end
		end
		if children then
			for _, child in ipairs(children) do
				child.Parent = inst
			end
		end
		if props and props.Parent ~= nil then
			inst.Parent = props.Parent
		end
		return inst
	end

	-- Rounded corner. radius: number (px) or UDim (e.g. UDim.new(1, 0) pill)
	function Utility.Round(parent, radius)
		return Utility.New("UICorner", {
			CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 10),
			Parent = parent,
		})
	end

	-- Border stroke. color may be a Color3 or a theme key string.
	function Utility.Stroke(parent, color, thickness, trans)
		local st = Utility.New("UIStroke", {
			Color = Color3.new(1, 1, 1),
			Thickness = thickness or 1,
			Transparency = trans or 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = parent,
		})
		if type(color) == "string" then
			Utility.Paint(st, "Color", color)
		elseif typeof(color) == "Color3" then
			st.Color = color
		end
		return st
	end

	-- Padding. Pad(inst, 10) all sides | Pad(inst, l, t, r, b)
	function Utility.Pad(parent, l, t, r, b)
		if type(l) == "number" and t == nil then
			t, r, b = l, l, l
		end
		return Utility.New("UIPadding", {
			PaddingLeft = UDim.new(0, l or 0),
			PaddingTop = UDim.new(0, t or 0),
			PaddingRight = UDim.new(0, r or 0),
			PaddingBottom = UDim.new(0, b or 0),
			Parent = parent,
		})
	end

	-- Linear gradient; colors may be theme keys or Color3.
	-- extra: { Rotation = deg, Transparency = NumberSequence }
	function Utility.Gradient(parent, c1, c2, rotation, extra)
		extra = extra or {}
		local function resolve(c)
			if type(c) == "string" then
				return Shared.Theme:Get(c)
			end
			return c
		end
		local g = Utility.New("UIGradient", {
			Color = ColorSequence.new(resolve(c1), resolve(c2)),
			Rotation = rotation or 90,
			Parent = parent,
		})
		if extra.Transparency then
			g.Transparency = extra.Transparency
		end
		if extra.Offset then
			g.Offset = extra.Offset
		end
		-- keep gradient endpoints fresh on theme switch
		if type(c1) == "string" or type(c2) == "string" then
			Shared.Theme:OnChange(function()
				if g.Parent then
					g.Color = ColorSequence.new(resolve(c1), resolve(c2))
				end
			end)
		end
		return g
	end

	-- Utility.ListLayout(parent, { Padding = 8, Direction = "Vertical"/"Horizontal",
	--   Horizontal = "Left"/"Center"/"Right", Vertical = "Top"/"Center"/"Bottom", Sort = "LayoutOrder" })
	function Utility.ListLayout(parent, o)
		o = o or {}
		return Utility.New("UIListLayout", {
			FillDirection = o.Direction == "Horizontal" and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
			Padding = UDim.new(0, o.Padding or 8),
			SortOrder = Enum.SortOrder[o.Sort or "LayoutOrder"],
			HorizontalAlignment = Enum.HorizontalAlignment[o.Horizontal or "Left"],
			VerticalAlignment = Enum.VerticalAlignment[o.Vertical or "Top"],
			Parent = parent,
		})
	end

	-- Keep a ScrollingFrame's CanvasSize in sync with a UIListLayout.
	function Utility.ConnectCanvas(scroll, layout, extra)
		extra = extra or 0
		local function update()
			scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + extra)
		end
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
		task.defer(update)
		return update
	end

	function Utility.ClearChildren(parent, predicate)
		for _, child in ipairs(parent:GetChildren()) do
			if not predicate or predicate(child) then
				child:Destroy()
			end
		end
	end

	----------------------------------------------------------------------
	-- Theming glue
	----------------------------------------------------------------------

	-- Assign + live-repaint helper. See Core/Theme.lua.
	function Utility.Paint(inst, prop, key)
		return Shared.Theme:Register(inst, prop, key)
	end

	function Utility.PaintMany(inst, map)
		for prop, key in pairs(map) do
			Utility.Paint(inst, prop, key)
		end
	end

	-- Hover tint helper: swaps a themed property between two theme keys.
	function Utility.HoverTint(gui, prop, restKey, hoverKey)
		gui.MouseEnter:Connect(function()
			Shared.Tween:Play(gui, "Fast", { [prop] = Shared.Theme:Get(hoverKey) })
		end)
		gui.MouseLeave:Connect(function()
			Shared.Tween:Play(gui, "Fast", { [prop] = Shared.Theme:Get(restKey) })
		end)
	end

	----------------------------------------------------------------------
	-- Input helpers
	----------------------------------------------------------------------

	local CLICK_TYPES = {
		[Enum.UserInputType.MouseButton1] = true,
		[Enum.UserInputType.Touch] = true,
	}

	function Utility.IsClick(input)
		return CLICK_TYPES[input.UserInputType] == true
	end

	function Utility.IsMove(input)
		return input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
	end

	function Utility.IsTyping()
		return Services.UserInputService:GetFocusedTextBox() ~= nil
	end

	-- Pretty name for a KeyCode/EnumItem ("RightShift" -> "RShift" stays raw,
	-- only common aliases shortened for compact chips)
	local KEY_ALIAS = {
		LeftControl = "LCtrl", RightControl = "RCtrl", LeftShift = "LShift",
		RightShift = "RShift", LeftAlt = "LAlt", RightAlt = "RAlt",
		Backspace = "Bksp", CapsLock = "Caps", Escape = "Esc",
		Return = "Enter", KeypadEnter = "NumEnter", PageUp = "PgUp",
		PageDown = "PgDn", Delete = "Del", Insert = "Ins",
		NumLock = "NumLk", ScrollLock = "ScrLk", PrintScreen = "PrtSc",
	}
	function Utility.KeyName(key)
		if key == nil then
			return "None"
		end
		if typeof(key) == "EnumItem" then
			local n = key.Name
			return KEY_ALIAS[n] or n
		end
		if type(key) == "string" then
			return KEY_ALIAS[key] or key
		end
		return tostring(key)
	end

	function Utility.KeyFromName(name)
		if name == nil or name == "None" or name == "" then
			return nil
		end
		for full, alias in pairs(KEY_ALIAS) do
			if alias == name then
				return Enum.KeyCode[full]
			end
		end
		local ok, item = pcall(function()
			return Enum.KeyCode[name]
		end)
		if ok then
			return item
		end
		return nil
	end

	----------------------------------------------------------------------
	-- Math / string / table
	----------------------------------------------------------------------

	function Utility.Clamp(v, lo, hi)
		return math.clamp(v, lo, hi)
	end

	function Utility.Lerp(a, b, t)
		return a + (b - a) * t
	end

	function Utility.RoundNum(num, decimals)
		if not decimals or decimals <= 0 then
			return math.floor(num + 0.5)
		end
		local m = 10 ^ decimals
		return math.floor(num * m + 0.5) / m
	end

	-- 1234567 -> "1,234,567"
	function Utility.FormatNumber(n)
		local s = tostring(math.floor(n + 0.5))
		local neg = s:sub(1, 1) == "-"
		if neg then
			s = s:sub(2)
		end
		local k
		repeat
			s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
		until k == 0
		return (neg and "-" or "") .. s
	end

	function Utility.Color3ToHex(c)
		return string.format("#%02X%02X%02X",
			math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
	end

	function Utility.HexToColor3(hex)
		hex = tostring(hex):gsub("#", ""):gsub("%s", "")
		if #hex == 3 then
			hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
		end
		assert(#hex == 6 and hex:match("^[%x]+$") ~= nil, "invalid hex color")
		return Color3.fromRGB(
			tonumber(hex:sub(1, 2), 16),
			tonumber(hex:sub(3, 4), 16),
			tonumber(hex:sub(5, 6), 16)
		)
	end

	function Utility.Trim(s)
		return (tostring(s):gsub("^%s*(.-)%s*$", "%1"))
	end

	function Utility.StartsWith(s, prefix)
		return s:sub(1, #prefix) == prefix
	end

	function Utility.UID(prefix)
		local guid = Services.HttpService:GenerateGUID(false):gsub("%-", ""):sub(1, 8)
		return (prefix and (prefix .. "_") or "") .. guid
	end

	-- Run fn no more often than `seconds` â€” calls collapse (last call wins).
	function Utility.Debounce(seconds, fn)
		local token = 0
		return function(...)
			token += 1
			local my = token
			local args = table.pack(...)
			task.delay(seconds, function()
				if my == token then
					fn(table.unpack(args, 1, args.n))
				end
			end)
		end
	end

	function Utility.ShallowCopy(t)
		local out = {}
		for k, v in pairs(t) do
			out[k] = v
		end
		return out
	end

	function Utility.DeepCopy(t)
		if type(t) ~= "table" then
			return t
		end
		local out = {}
		for k, v in pairs(t) do
			out[k] = Utility.DeepCopy(v)
		end
		return out
	end

	-- Fill nil gaps of `into` from `defaults` (non-recursive).
	function Utility.FillDefaults(into, defaults)
		for k, v in pairs(defaults or {}) do
			if into[k] == nil then
				into[k] = v
			end
		end
		return into
	end

	-- Normalize the dual calling convention used across the library:
	--   Section:Toggle("Title", false, cb)          -- positional
	--   Section:Toggle({Title=..., Default=..., Callback=fn, Flag=..., ...})
	function Utility.NormalizeOptions(first, rest, defaults, positional)
		local o = {}
		for k, v in pairs(defaults or {}) do
			o[k] = v
		end
		if type(first) == "table" then
			for k, v in pairs(first) do
				o[k] = v
			end
			return o
		end
		if positional then
			local args = { first }
			if rest then
				for i, v in ipairs(rest) do
					args[i + 1] = v
				end
			end
			for i, key in ipairs(positional) do
				if args[i] ~= nil then
					o[key] = args[i]
				end
			end
		end
		return o
	end

	----------------------------------------------------------------------
	-- Value encoding for configs (survive JSON round-trips)
	----------------------------------------------------------------------

	function Utility.EncodeValue(value)
		local t = typeof(value)
		if t == "Color3" then
			return { __type = "Color3", r = value.R, g = value.G, b = value.B }
		elseif t == "EnumItem" then
			return { __type = "Enum", enum = tostring(value.EnumType), name = value.Name }
		elseif t == "Vector2" then
			return { __type = "Vector2", x = value.X, y = value.Y }
		elseif t == "UDim2" then
			return {
				__type = "UDim2",
				xs = value.X.Scale, xo = value.X.Offset,
				ys = value.Y.Scale, yo = value.Y.Offset,
			}
		elseif t == "ColorSequence" then
			local pts = {}
			for _, kp in ipairs(value.Keypoints) do
				table.insert(pts, { t = kp.Time, r = kp.Value.R, g = kp.Value.G, b = kp.Value.B })
			end
			return { __type = "ColorSequence", points = pts }
		elseif t == "table" then
			local out = {}
			for k, v in pairs(value) do
				if type(k) == "number" or type(k) == "string" then
					out[k] = Utility.EncodeValue(v)
				end
			end
			return out
		elseif t == "number" or t == "string" or t == "boolean" then
			return value
		end
		-- unsupported types degrade to their string form
		return tostring(value)
	end

	function Utility.DecodeValue(value)
		if type(value) == "table" then
			local tag = value.__type
			if tag == "Color3" then
				return Color3.new(
					Utility.Clamp(tonumber(value.r) or 0, 0, 1),
					Utility.Clamp(tonumber(value.g) or 0, 0, 1),
					Utility.Clamp(tonumber(value.b) or 0, 0, 1)
				)
			elseif tag == "Enum" then
				local ok, item = pcall(function()
					return Enum[value.enum][value.name]
				end)
				if ok then
					return item
				end
				return nil
			elseif tag == "Vector2" then
				return Vector2.new(value.x or 0, value.y or 0)
			elseif tag == "UDim2" then
				return UDim2.new(value.xs or 0, value.xo or 0, value.ys or 0, value.yo or 0)
			elseif tag == "ColorSequence" and type(value.points) == "table" then
				local pts = {}
				for _, p in ipairs(value.points) do
					table.insert(pts, ColorSequenceKeypoint.new(
						Utility.Clamp(tonumber(p.t) or 0, 0, 1),
						Color3.new(p.r or 0, p.g or 0, p.b or 0)
					))
				end
				table.sort(pts, function(a, b)
					return a.Time < b.Time
				end)
				if #pts == 1 then
					pts[2] = pts[1]
				end
				if #pts > 0 then
					return ColorSequence.new(pts)
				end
				return ColorSequence.new(Color3.new(1, 1, 1))
			end
			local out = {}
			for k, v in pairs(value) do
				out[k] = Utility.DecodeValue(v)
			end
			return out
		end
		return value
	end

	----------------------------------------------------------------------
	-- Filesystem facade (executor APIs are optional / guarded)
	----------------------------------------------------------------------

	local FS = {}
	Utility.FS = FS

	FS.Available = type(writefile) == "function" and type(readfile) == "function"

	function FS.Read(path)
		if not FS.Available then
			return nil
		end
		if type(isfile) == "function" and not isfile(path) then
			return nil
		end
		local ok, data = pcall(readfile, path)
		if ok then
			return data
		end
		return nil
	end

	function FS.Write(path, contents)
		if not FS.Available then
			return false
		end
		local ok = pcall(writefile, path, contents)
		return ok
	end

	function FS.Append(path, contents)
		if not type(appendfile) == "function" then
			return false
		end
		local ok = pcall(appendfile, path, contents)
		return ok
	end

	function FS.Exists(path)
		if type(isfile) ~= "function" then
			return false
		end
		local ok, res = pcall(isfile, path)
		return ok and res == true
	end

	function FS.Delete(path)
		if type(delfile) ~= "function" then
			return false
		end
		local ok = pcall(delfile, path)
		return ok
	end

	function FS.FolderExists(path)
		if type(isfolder) ~= "function" then
			return false
		end
		local ok, res = pcall(isfolder, path)
		return ok and res == true
	end

	function FS.EnsureFolder(path)
		if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
			return
		end
		local parts = string.split(path, "/")
		local cur = ""
		for _, part in ipairs(parts) do
			cur = cur == "" and part or (cur .. "/" .. part)
			local ok, exists = pcall(isfolder, cur)
			if ok and not exists then
				pcall(makefolder, cur)
			end
		end
	end

	function FS.List(path)
		if type(listfiles) ~= "function" then
			return {}
		end
		local ok, files = pcall(listfiles, path)
		if ok and type(files) == "table" then
			return files
		end
		return {}
	end

	----------------------------------------------------------------------
	-- ScreenGui parenting with detection-avoidance fallbacks
	----------------------------------------------------------------------

	function Utility.ProtectGui(gui)
		pcall(function()
			gui.OnTopOfCoreBlur = true
		end)
		if type(syn) == "table" and type(syn.protect_gui) == "function" then
			pcall(syn.protect_gui, gui)
		end
		local parented = false
		if type(gethui) == "function" then
			local ok, parent = pcall(gethui)
			if ok and parent then
				gui.Parent = parent
				parented = true
			end
		end
		if not parented then
			local ok = pcall(function()
				gui.Parent = Services.CoreGui
			end)
			if not ok then
				gui.Parent = Services.LocalPlayer:WaitForChild("PlayerGui")
			end
		end
		return gui
	end

	----------------------------------------------------------------------
	-- Text measurement
	----------------------------------------------------------------------

	function Utility.TextSize(text, fontSize, font, maxWidth)
		local ok, size = pcall(function()
			return Services.TextService:GetTextSize(
				text, fontSize or 13,
				font or Enum.Font.Gotham,
				Vector2.new(maxWidth or 1e5, 1e5)
			)
		end)
		if ok then
			return size
		end
		-- crude fallback: ~0.55em average glyph width
		return Vector2.new(#text * (fontSize or 13) * 0.55, fontSize or 13)
	end

	----------------------------------------------------------------------
	-- Misc interaction eye-candy
	----------------------------------------------------------------------

	-- Material-style click ripple on a TextButton/ImageButton.
	-- Utility.Ripple(button) -> expand from click point
	-- Utility.Ripple(button, x, y) absolute
	function Utility.Ripple(button, x, y, colorKey)
		if not button or not button.Parent then
			return
		end
		local abs = button.AbsolutePosition
		local size = button.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local px = x and (x - abs.X) or (size.X / 2)
		local py = y and (y - abs.Y) or (size.Y / 2)

		local ripple = Utility.New("Frame", {
			Name = "Ripple",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = type(colorKey) == "string" and Shared.Theme:Get(colorKey) or Color3.new(1, 1, 1),
			BackgroundTransparency = 0.72,
			Position = UDim2.new(0, px, 0, py),
			Size = UDim2.fromOffset(0, 0),
			BorderSizePixel = 0,
			ZIndex = math.max((button.ZIndex or 1) - 1, 1),
			Parent = button,
		})
		Utility.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ripple })

		-- diameter needed to cover farthest corner
		local d = math.max(size.X, size.Y)
		local corners = {
			Vector2.new(0, 0), Vector2.new(size.X, 0),
			Vector2.new(0, size.Y), Vector2.new(size.X, size.Y),
		}
		for _, c in ipairs(corners) do
			d = math.max(d, (c - Vector2.new(px, py)).Magnitude * 2)
		end

		Shared.Tween:Play(ripple, "Ripple", { Size = UDim2.fromOffset(d, d) })
		Shared.Tween:Play(ripple, "RippleFade", { BackgroundTransparency = 1 })
		task.delay(0.6, function()
			if ripple.Parent then
				ripple:Destroy()
			end
		end)
		return ripple
	end

	-- Follow-the-mouse global short-circuit garbage collection helper used
	-- by Window cleanup: registers instances/connections/tweaks to destroy.
	function Utility.Maid()
		local Maid = {}
		Maid.ClassName = "Maid"
		Maid.__index = Maid

		function Maid.new()
			return setmetatable({ _items = {} }, Maid)
		end

		function Maid:Give(item)
			table.insert(self._items, item)
			return item
		end

		function Maid:Clean()
			for _, item in ipairs(self._items) do
				local t = typeof(item)
				if t == "RBXScriptConnection" then
					item:Disconnect()
				elseif t == "Instance" then
					item:Destroy()
				elseif t == "table" then
					if item.Destroy then
						item:Destroy()
					elseif item.Disconnect then
						item:Disconnect()
					end
				end
			end
			table.clear(self._items)
		end

		return Maid.new()
	end

	-- Consistent font accessors (house style)
	function Utility.FontBold()
		return Enum.Font.GothamBold
	end
	function Utility.FontMedium()
		return Enum.Font.GothamMedium
	end
	function Utility.FontRegular()
		return Enum.Font.Gotham
	end
	function Utility.FontMono()
		return Enum.Font.Code
	end

	-- A tweened UIScale convenience
	function Utility.ScaleIn(frame, targetScale, preset)
		local sc = Utility.New("UIScale", { Scale = (targetScale or 1) * 0.94, Parent = frame })
		Shared.Tween:Play(sc, preset or "Spring", { Scale = targetScale or 1 })
		return sc
	end

	return Utility
end

end)()

--===========================[ Core.Tween ]===========================--
__MODULES["Core.Tween"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Core/Tween.lua
-- Animation engine: named TweenInfo presets, a math easing library for custom
-- loops, numeric (non-Instance) animation, chaining and grouping.
--
--   Shared.Tween:Play(inst, "Fast", { BackgroundTransparency = 0.4 }) -> Tween
--   Shared.Tween:Play(inst, { Time = 0.3, Style = "Quint", Direction = "Out" }, props)
--   Shared.Tween:Number(0, 1, 0.25, "OutQuart", function(v) ... end) -> cancel fn
--   Shared.Tween.Chain(t1, t2); Shared.Tween.Group({t1, t2})
--   Shared.Tween.Enabled = false  -- hard-disable all motion (accessibility)
--==========================================================================]]

return function(Shared)
	local Tween = {}
	local Services = Shared.Services
	local TweenService = Services.TweenService

	----------------------------------------------------------------------
	-- Global switches
	----------------------------------------------------------------------

	Tween.Enabled = true     -- master switch, false = everything applies instantly
	Tween.Speed = 1          -- global multiplier (2 = twice as fast)

	----------------------------------------------------------------------
	-- Easing math (t in [0,1] -> eased t) for custom / numeric animations
	----------------------------------------------------------------------

	local E = {}
	Tween.Easings = E

	local PI = math.pi

	function E.Linear(t)
		return t
	end

	function E.InQuad(t)
		return t * t
	end
	function E.OutQuad(t)
		return t * (2 - t)
	end
	function E.InOutQuad(t)
		return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t
	end

	function E.InCubic(t)
		return t * t * t
	end
	function E.OutCubic(t)
		local u = t - 1
		return u * u * u + 1
	end
	function E.InOutCubic(t)
		return t < 0.5 and 4 * t * t * t or (t - 1) * (2 * t - 2) * (2 * t - 2) + 1
	end

	function E.InQuart(t)
		return t * t * t * t
	end
	function E.OutQuart(t)
		local u = t - 1
		return 1 - u * u * u * u
	end
	function E.InOutQuart(t)
		if t < 0.5 then
			return 8 * t * t * t * t
		end
		local u = t - 1
		return 1 - 8 * u * u * u * u
	end

	function E.InQuint(t)
		return t * t * t * t * t
	end
	function E.OutQuint(t)
		local u = t - 1
		return 1 + u * u * u * u * u
	end
	function E.InOutQuint(t)
		if t < 0.5 then
			return 16 * t * t * t * t * t
		end
		local u = t - 1
		return 1 + 16 * u * u * u * u * u
	end

	function E.InSine(t)
		return 1 - math.cos(t * PI / 2)
	end
	function E.OutSine(t)
		return math.sin(t * PI / 2)
	end
	function E.InOutSine(t)
		return -(math.cos(PI * t) - 1) / 2
	end

	function E.InExpo(t)
		return t == 0 and 0 or 2 ^ (10 * (t - 1))
	end
	function E.OutExpo(t)
		return t == 1 and 1 or 1 - 2 ^ (-10 * t)
	end
	function E.InOutExpo(t)
		if t == 0 or t == 1 then
			return t
		end
		if t < 0.5 then
			return 2 ^ (20 * t - 10) / 2
		end
		return (2 - 2 ^ (-20 * t + 10)) / 2
	end

	function E.InCirc(t)
		return 1 - math.sqrt(math.max(0, 1 - t * t))
	end
	function E.OutCirc(t)
		local u = t - 1
		return math.sqrt(math.max(0, 1 - u * u))
	end
	function E.InOutCirc(t)
		if t < 0.5 then
			return (1 - math.sqrt(math.max(0, 1 - 4 * t * t))) / 2
		end
		local u = 2 * t - 2
		return (math.sqrt(math.max(0, 1 - u * u)) + 1) / 2
	end

	function E.InBack(t)
		local s = 1.70158
		return t * t * ((s + 1) * t - s)
	end
	function E.OutBack(t)
		local s = 1.70158
		local u = t - 1
		return 1 + u * u * ((s + 1) * u + s)
	end
	function E.InOutBack(t)
		local s = 1.70158 * 1.525
		if t < 0.5 then
			return (2 * t) ^ 2 * ((s + 1) * 2 * t - s) / 2
		end
		local u = 2 * t - 2
		return (u * u * ((s + 1) * u + s) + 2) / 2
	end

	function E.OutBounce(t)
		if t < 1 / 2.75 then
			return 7.5625 * t * t
		elseif t < 2 / 2.75 then
			local u = t - 1.5 / 2.75
			return 7.5625 * u * u + 0.75
		elseif t < 2.5 / 2.75 then
			local u = t - 2.25 / 2.75
			return 7.5625 * u * u + 0.9375
		else
			local u = t - 2.625 / 2.75
			return 7.5625 * u * u + 0.984375
		end
	end
	function E.InBounce(t)
		return 1 - E.OutBounce(1 - t)
	end
	function E.InOutBounce(t)
		if t < 0.5 then
			return E.InBounce(t * 2) / 2
		end
		return (1 + E.OutBounce(t * 2 - 1)) / 2
	end

	function E.InElastic(t)
		if t == 0 or t == 1 then
			return t
		end
		return -(2 ^ (10 * (t - 1)) * math.sin((t - 1.1) * 5 * PI))
	end
	function E.OutElastic(t)
		if t == 0 or t == 1 then
			return t
		end
		return 2 ^ (-10 * t) * math.sin((t - 0.1) * 5 * PI) + 1
	end
	function E.InOutElastic(t)
		if t == 0 or t == 1 then
			return t
		end
		if t < 0.5 then
			return -(2 ^ (20 * t - 10) * math.sin((20 * t - 11.125) * (2 * PI) / 4.5)) / 2
		end
		return (2 ^ (-20 * t + 10) * math.sin((20 * t - 11.125) * (2 * PI) / 4.5)) / 2 + 1
	end

	-- gentle overshoot used by knobs & popups
	function E.Springy(t)
		return 1 + 1.5 * (t - 1) ^ 3 + 0.75 * (t - 1) ^ 2
	end

	function E.Get(name)
		if type(name) == "function" then
			return name
		end
		return E[name] or E.OutQuad
	end

	----------------------------------------------------------------------
	-- Preset table: name -> TweenInfo factory (so Speed scaling applies)
	----------------------------------------------------------------------

	local function TI(time, style, dir, repeats, rev, delay)
		return { Time = time, Style = style, Direction = dir, Repeats = repeats or 0, Reverses = rev or false, Delay = delay or 0 }
	end

	Tween.Presets = {
		Instant = TI(0.001, "Linear", "Out"),
		Micro = TI(0.08, "Quad", "Out"),
		Fast = TI(0.15, "Quad", "Out"),
		Quick = TI(0.2, "Quint", "Out"),
		Snappy = TI(0.24, "Quint", "Out"),
		Smooth = TI(0.32, "Exponential", "Out"),
		Medium = TI(0.4, "Quint", "Out"),
		Emphasized = TI(0.5, "Exponential", "Out"),
		Slow = TI(0.65, "Sine", "Out"),
		Spring = TI(0.42, "Back", "Out"),
		Springy = TI(0.5, "Back", "Out"),
		Bounce = TI(0.55, "Bounce", "Out"),
		Elastic = TI(0.7, "Elastic", "Out"),
		Pop = TI(0.28, "Back", "Out"),
		Fade = TI(0.25, "Sine", "Out"),
		Ripple = TI(0.42, "Quad", "Out"),
		RippleFade = TI(0.5, "Quad", "In"),
		PanelSlide = TI(0.35, "Quart", "Out"),
		Dialog = TI(0.34, "Back", "Out"),
		TabSwitch = TI(0.3, "Quint", "Out"),
	}

	-- Build a TweenInfo from: preset name | TweenInfo | descriptor table
	local function BuildInfo(spec)
		if typeof(spec) == "TweenInfo" then
			return spec
		end
		if type(spec) == "string" then
			local p = Tween.Presets[spec] or Tween.Presets.Fast
			spec = p
		end
		if type(spec) == "table" then
			local time = (spec.Time or 0.2) / math.max(Tween.Speed, 0.01)
			local style = Enum.EasingStyle.Linear
			local dir = Enum.EasingDirection.Out
			if type(spec.Style) == "string" and Enum.EasingStyle[spec.Style] then
				style = Enum.EasingStyle[spec.Style]
			elseif typeof(spec.Style) == "EnumItem" then
				style = spec.Style
			end
			if spec.Direction then
				if type(spec.Direction) == "string" and Enum.EasingDirection[spec.Direction] then
					dir = Enum.EasingDirection[spec.Direction]
				elseif typeof(spec.Direction) == "EnumItem" then
					dir = spec.Direction
				end
			end
			if not Tween.Enabled then
				time = 0.001
			end
			return TweenInfo.new(time, style, dir, spec.Repeats or 0, spec.Reverses or false, spec.Delay or 0)
		end
		return TweenInfo.new(0.2)
	end

	Tween.BuildInfo = BuildInfo

	----------------------------------------------------------------------
	-- Instance tweening
	----------------------------------------------------------------------

	-- Play an instance tween. Returns the Tween (or nil when instantly applied).
	function Tween:Play(inst, spec, props)
		if not inst then
			return nil
		end
		if not Tween.Enabled then
			for k, v in pairs(props) do
				inst[k] = v
			end
			return nil
		end
		local info = BuildInfo(spec)
		local ok, t = pcall(function()
			return TweenService:Create(inst, info, props)
		end)
		if not ok then
			return nil
		end
		t:Play()
		return t
	end

	function Tween:Stop(t)
		if typeof(t) == "Tween" then
			pcall(function()
				t:Cancel()
			end)
		end
	end

	-- Play tweens one after another. Returns a Signal that fires on completion.
	function Tween.Chain(...)
		local tweens = table.pack(...)
		local done = Shared.Signal.new()
		task.spawn(function()
			for i = 1, tweens.n do
				local t = tweens[i]
				if typeof(t) == "Tween" then
					if t.PlaybackState == Enum.PlaybackState.Begin then
						t:Play()
					end
					if Tween.Enabled then
						t.Completed:Wait()
					end
				end
			end
			done:Fire()
		end)
		return done
	end

	-- Wait for all tweens to complete; returns Signal.
	function Tween.Group(tweens)
		local done = 0
		local total = 0
		for _ in ipairs(tweens) do
			total = total + 1
		end
		local allDone = Shared.Signal.new()
		if total == 0 then
			task.defer(function()
				allDone:Fire()
			end)
			return allDone
		end
		for _, t in ipairs(tweens) do
			if typeof(t) == "Tween" then
				task.spawn(function()
					if Tween.Enabled then
						t.Completed:Wait()
					end
					done += 1
					if done >= total then
						allDone:Fire()
					end
				end)
			else
				done += 1
				if done >= total then
					allDone:Fire()
				end
			end
		end
		return allDone
	end

	----------------------------------------------------------------------
	-- Numeric animation (for custom paint code: ripples, pulses, scrims)
	----------------------------------------------------------------------

	-- Tween:Number({
	--   From=0, To=1, Duration=0.3, Easing="OutQuart" or fn,
	--   OnUpdate=function(v) end, OnComplete=function() end
	-- }) -> cancel()
	function Tween:Number(cfg)
		local from = cfg.From or 0
		local to = cfg.To or 1
		local duration = math.max(cfg.Duration or 0.3, 0.001)
		if not Tween.Enabled then
			if cfg.OnUpdate then
				cfg.OnUpdate(to)
			end
			if cfg.OnComplete then
				cfg.OnComplete()
			end
			return function() end
		end
		duration = duration / math.max(Tween.Speed, 0.01)
		local ease = E.Get(cfg.Easing or "OutQuad")
		local cancelled = false
		local elapsed = -(cfg.Delay or 0)
		local conn
		conn = Services.RunService.RenderStepped:Connect(function(dt)
			if cancelled then
				conn:Disconnect()
				return
			end
			elapsed += dt
			if elapsed < 0 then
				return
			end
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local v = from + (to - from) * ease(alpha)
			if cfg.OnUpdate then
				cfg.OnUpdate(v, alpha)
			end
			if alpha >= 1 then
				conn:Disconnect()
				if cfg.OnComplete then
					cfg.OnComplete()
				end
			end
		end)
		return function()
			cancelled = true
		end
	end

	-- Endless pulsing: Tween:Pulse(inst, "BackgroundTransparency", 0.4, 0.8, 1.2)
	-- returns cancel function
	function Tween:Pulse(inst, prop, minV, maxV, period)
		local cancelled = false
		local elapsed = 0
		local conn
		conn = Services.RunService.RenderStepped:Connect(function(dt)
			if cancelled or not inst or not inst.Parent then
				conn:Disconnect()
				return
			end
			if not Tween.Enabled then
				inst[prop] = minV
				return
			end
			elapsed += dt
			local s = (math.sin(elapsed / period * 2 * PI) + 1) / 2
			inst[prop] = minV + (maxV - minV) * s
		end)
		return function()
			cancelled = true
			pcall(function()
				conn:Disconnect()
			end)
		end
	end

	-- Rotation spinner for loader icons
	function Tween:Spin(inst, period)
		local cancelled = false
		task.spawn(function()
			while not cancelled and inst and inst.Parent do
				local t = self:Play(inst, { Time = period or 1, Style = "Linear" }, { Rotation = (inst.Rotation + 360) % 360 })
				if t then
					t.Completed:Wait()
				else
					break
				end
			end
		end)
		return function()
			cancelled = true
		end
	end

	return Tween
end

end)()

--===========================[ Core.IconMap ]===========================--
__MODULES["Core.IconMap"] = (function()
-- AUTO-GENERATED by tools/ExtractIcons.ps1 -- do not edit by hand.
-- Icon data: latte-soft/lucide-roblox 0.1.3 (MIT License) https://github.com/latte-soft/lucide-roblox
-- Icons: Lucide 0.363.0 (ISC License) https://lucide.dev
-- Format per entry: ["name"] = { AssetId, RectWidth, RectHeight, OffsetX, OffsetY }
return {
	["activity"] = { 16898612629, 48, 48, 514, 771 },
	["alarm-clock"] = { 16898612629, 48, 48, 257, 820 },
	["alert-circle"] = { 16898612629, 48, 48, 869, 0 },
	["alert-octagon"] = { 16898612629, 48, 48, 820, 49 },
	["alert-triangle"] = { 16898612629, 48, 48, 771, 98 },
	["anchor"] = { 16898612629, 48, 48, 306, 869 },
	["antenna"] = { 16898612629, 48, 48, 869, 563 },
	["aperture"] = { 16898612629, 48, 48, 771, 661 },
	["archive"] = { 16898612629, 48, 48, 918, 49 },
	["arrow-down"] = { 16898612629, 48, 48, 967, 49 },
	["arrow-left"] = { 16898612629, 48, 48, 98, 918 },
	["arrow-right"] = { 16898612629, 48, 48, 453, 820 },
	["arrow-up"] = { 16898612629, 48, 48, 967, 355 },
	["arrow-up-right"] = { 16898612629, 48, 48, 918, 147 },
	["asterisk"] = { 16898612629, 48, 48, 869, 453 },
	["at-sign"] = { 16898612629, 48, 48, 453, 869 },
	["atom"] = { 16898612629, 48, 48, 404, 918 },
	["award"] = { 16898612629, 48, 48, 918, 661 },
	["axe"] = { 16898612629, 48, 48, 869, 710 },
	["badge-check"] = { 16898612629, 48, 48, 967, 147 },
	["ban"] = { 16898612629, 48, 48, 196, 967 },
	["battery"] = { 16898612629, 48, 48, 967, 857 },
	["battery-charging"] = { 16898612629, 48, 48, 771, 955 },
	["bell"] = { 16898612819, 48, 48, 820, 257 },
	["bell-off"] = { 16898612819, 48, 48, 771, 49 },
	["bluetooth"] = { 16898612819, 48, 48, 771, 355 },
	["bold"] = { 16898612819, 48, 48, 355, 771 },
	["bomb"] = { 16898612819, 48, 48, 257, 869 },
	["book"] = { 16898612819, 48, 48, 820, 612 },
	["bookmark"] = { 16898612819, 48, 48, 514, 918 },
	["box"] = { 16898612819, 48, 48, 771, 196 },
	["briefcase"] = { 16898612819, 48, 48, 771, 453 },
	["brush"] = { 16898612819, 48, 48, 404, 820 },
	["bug"] = { 16898612819, 48, 48, 257, 967 },
	["building"] = { 16898612819, 48, 48, 918, 563 },
	["calculator"] = { 16898612819, 48, 48, 563, 918 },
	["calendar"] = { 16898612819, 48, 48, 355, 918 },
	["camera"] = { 16898612819, 48, 48, 967, 563 },
	["cast"] = { 16898612819, 48, 48, 869, 453 },
	["check"] = { 16898612819, 48, 48, 710, 869 },
	["check-circle"] = { 16898612819, 48, 48, 869, 710 },
	["check-square"] = { 16898612819, 48, 48, 771, 808 },
	["chevron-down"] = { 16898612819, 48, 48, 196, 918 },
	["chevron-left"] = { 16898612819, 48, 48, 404, 967 },
	["chevron-right"] = { 16898612819, 48, 48, 869, 759 },
	["chevron-up"] = { 16898612819, 48, 48, 710, 918 },
	["chevrons-up-down"] = { 16898612819, 48, 48, 918, 759 },
	["circle"] = { 16898613044, 48, 48, 771, 355 },
	["clipboard"] = { 16898613044, 48, 48, 49, 869 },
	["clock"] = { 16898613044, 48, 48, 771, 661 },
	["cloud"] = { 16898613044, 48, 48, 918, 306 },
	["cloud-download"] = { 16898613044, 48, 48, 612, 820 },
	["cloud-upload"] = { 16898613044, 48, 48, 967, 257 },
	["code"] = { 16898613044, 48, 48, 355, 869 },
	["codepen"] = { 16898613044, 48, 48, 306, 918 },
	["codesandbox"] = { 16898613044, 48, 48, 257, 967 },
	["coffee"] = { 16898613044, 48, 48, 967, 514 },
	["cog"] = { 16898613044, 48, 48, 918, 563 },
	["coins"] = { 16898613044, 48, 48, 869, 612 },
	["command"] = { 16898613044, 48, 48, 563, 918 },
	["compass"] = { 16898613044, 48, 48, 514, 967 },
	["copy"] = { 16898613044, 48, 48, 918, 612 },
	["cpu"] = { 16898613044, 48, 48, 196, 869 },
	["credit-card"] = { 16898613044, 48, 48, 98, 967 },
	["crop"] = { 16898613044, 48, 48, 918, 404 },
	["crosshair"] = { 16898613044, 48, 48, 453, 869 },
	["crown"] = { 16898613044, 48, 48, 404, 918 },
	["database"] = { 16898613044, 48, 48, 710, 869 },
	["delete"] = { 16898613044, 48, 48, 661, 918 },
	["diamond"] = { 16898613044, 48, 48, 196, 918 },
	["disc"] = { 16898613044, 48, 48, 661, 967 },
	["dollar-sign"] = { 16898613044, 48, 48, 820, 857 },
	["download"] = { 16898613044, 48, 48, 820, 906 },
	["droplet"] = { 16898613044, 48, 48, 820, 955 },
	["pencil"] = { 16898613699, 48, 48, 820, 257 },
	["pen-line"] = { 16898613699, 48, 48, 771, 514 },
	["square-pen"] = { 16898613777, 48, 48, 710, 820 },
	["external-link"] = { 16898613353, 48, 48, 257, 820 },
	["eye"] = { 16898613353, 48, 48, 771, 563 },
	["eye-off"] = { 16898613353, 48, 48, 820, 514 },
	["fast-forward"] = { 16898613353, 48, 48, 820, 49 },
	["feather"] = { 16898613353, 48, 48, 771, 98 },
	["file"] = { 16898613353, 48, 48, 820, 661 },
	["file-minus"] = { 16898613353, 48, 48, 820, 612 },
	["file-plus"] = { 16898613353, 48, 48, 918, 49 },
	["file-text"] = { 16898613353, 48, 48, 869, 355 },
	["film"] = { 16898613353, 48, 48, 710, 771 },
	["filter"] = { 16898613353, 48, 48, 612, 869 },
	["flag"] = { 16898613353, 48, 48, 98, 918 },
	["flame"] = { 16898613353, 48, 48, 967, 306 },
	["flask-conical"] = { 16898613353, 48, 48, 453, 820 },
	["folder"] = { 16898613353, 48, 48, 404, 967 },
	["folder-plus"] = { 16898613353, 48, 48, 661, 918 },
	["frown"] = { 16898613353, 48, 48, 967, 196 },
	["gamepad-2"] = { 16898613353, 48, 48, 710, 967 },
	["gauge"] = { 16898613353, 48, 48, 771, 955 },
	["gem"] = { 16898613353, 48, 48, 918, 857 },
	["ghost"] = { 16898613353, 48, 48, 869, 906 },
	["gift"] = { 16898613353, 48, 48, 820, 955 },
	["git-branch"] = { 16898613353, 48, 48, 918, 906 },
	["github"] = { 16898613509, 48, 48, 0, 820 },
	["glass-water"] = { 16898613509, 48, 48, 771, 306 },
	["globe"] = { 16898613509, 48, 48, 771, 563 },
	["grab"] = { 16898613509, 48, 48, 514, 820 },
	["grid-2x2"] = { 16898613509, 48, 48, 771, 98 },
	["group"] = { 16898613509, 48, 48, 820, 306 },
	["hammer"] = { 16898613509, 48, 48, 306, 820 },
	["hard-drive"] = { 16898613509, 48, 48, 820, 98 },
	["hash"] = { 16898613509, 48, 48, 147, 771 },
	["headphones"] = { 16898613509, 48, 48, 306, 869 },
	["heart"] = { 16898613509, 48, 48, 661, 771 },
	["hexagon"] = { 16898613509, 48, 48, 967, 0 },
	["highlighter"] = { 16898613509, 48, 48, 918, 49 },
	["history"] = { 16898613509, 48, 48, 869, 98 },
	["home"] = { 16898613509, 48, 48, 820, 147 },
	["hourglass"] = { 16898613509, 48, 48, 49, 918 },
	["image"] = { 16898613509, 48, 48, 306, 918 },
	["inbox"] = { 16898613509, 48, 48, 918, 563 },
	["infinity"] = { 16898613509, 48, 48, 661, 820 },
	["info"] = { 16898613509, 48, 48, 612, 869 },
	["italic"] = { 16898613509, 48, 48, 967, 49 },
	["key"] = { 16898613509, 48, 48, 869, 404 },
	["keyboard"] = { 16898613509, 48, 48, 453, 820 },
	["lamp"] = { 16898613509, 48, 48, 869, 661 },
	["laptop"] = { 16898613509, 48, 48, 563, 967 },
	["layers"] = { 16898613509, 48, 48, 98, 967 },
	["layout"] = { 16898613509, 48, 48, 967, 612 },
	["layout-grid"] = { 16898613509, 48, 48, 918, 404 },
	["library"] = { 16898613509, 48, 48, 710, 869 },
	["life-buoy"] = { 16898613509, 48, 48, 661, 918 },
	["lightbulb"] = { 16898613509, 48, 48, 918, 196 },
	["link"] = { 16898613509, 48, 48, 918, 453 },
	["link-2"] = { 16898613509, 48, 48, 967, 404 },
	["list"] = { 16898613509, 48, 48, 869, 808 },
	["loader"] = { 16898613509, 48, 48, 710, 967 },
	["lock"] = { 16898613509, 48, 48, 918, 857 },
	["log-in"] = { 16898613509, 48, 48, 869, 906 },
	["log-out"] = { 16898613509, 48, 48, 820, 955 },
	["magnet"] = { 16898613509, 48, 48, 967, 906 },
	["mail"] = { 16898613613, 48, 48, 820, 0 },
	["map"] = { 16898613613, 48, 48, 306, 771 },
	["map-pin"] = { 16898613613, 48, 48, 820, 257 },
	["maximize"] = { 16898613613, 48, 48, 771, 563 },
	["maximize-2"] = { 16898613613, 48, 48, 820, 514 },
	["medal"] = { 16898613613, 48, 48, 563, 771 },
	["megaphone"] = { 16898613613, 48, 48, 869, 0 },
	["menu"] = { 16898613613, 48, 48, 49, 820 },
	["message-circle"] = { 16898613613, 48, 48, 563, 820 },
	["message-square"] = { 16898613613, 48, 48, 355, 820 },
	["mic"] = { 16898613613, 48, 48, 820, 612 },
	["mic-off"] = { 16898613613, 48, 48, 918, 514 },
	["minimize"] = { 16898613613, 48, 48, 918, 49 },
	["minimize-2"] = { 16898613613, 48, 48, 967, 0 },
	["minus"] = { 16898613613, 48, 48, 771, 196 },
	["minus-circle"] = { 16898613613, 48, 48, 869, 98 },
	["monitor"] = { 16898613613, 48, 48, 404, 820 },
	["moon"] = { 16898613613, 48, 48, 306, 918 },
	["more-horizontal"] = { 16898613613, 48, 48, 257, 967 },
	["more-vertical"] = { 16898613613, 48, 48, 967, 514 },
	["mouse"] = { 16898613613, 48, 48, 563, 918 },
	["move"] = { 16898613613, 48, 48, 453, 820 },
	["music"] = { 16898613613, 48, 48, 967, 563 },
	["navigation"] = { 16898613613, 48, 48, 771, 759 },
	["network"] = { 16898613613, 48, 48, 710, 820 },
	["octagon"] = { 16898613613, 48, 48, 404, 918 },
	["package"] = { 16898613613, 48, 48, 918, 196 },
	["paintbrush"] = { 16898613613, 48, 48, 918, 453 },
	["palette"] = { 16898613613, 48, 48, 453, 918 },
	["pause"] = { 16898613699, 48, 48, 0, 771 },
	["pen-tool"] = { 16898613699, 48, 48, 820, 0 },
	["percent"] = { 16898613699, 48, 48, 771, 563 },
	["phone"] = { 16898613699, 48, 48, 0, 869 },
	["pie-chart"] = { 16898613699, 48, 48, 869, 514 },
	["pin"] = { 16898613699, 48, 48, 918, 0 },
	["play"] = { 16898613699, 48, 48, 918, 257 },
	["plug"] = { 16898613699, 48, 48, 404, 771 },
	["plug-zap"] = { 16898613699, 48, 48, 771, 404 },
	["plus"] = { 16898613699, 48, 48, 257, 918 },
	["plus-circle"] = { 16898613699, 48, 48, 355, 820 },
	["pocket"] = { 16898613699, 48, 48, 869, 563 },
	["power"] = { 16898613699, 48, 48, 820, 147 },
	["printer"] = { 16898613699, 48, 48, 196, 771 },
	["puzzle"] = { 16898613699, 48, 48, 49, 918 },
	["quote"] = { 16898613699, 48, 48, 918, 306 },
	["radio"] = { 16898613699, 48, 48, 306, 918 },
	["refresh-ccw"] = { 16898613699, 48, 48, 820, 453 },
	["refresh-cw"] = { 16898613699, 48, 48, 404, 869 },
	["repeat"] = { 16898613699, 48, 48, 820, 710 },
	["rewind"] = { 16898613699, 48, 48, 563, 967 },
	["rocket"] = { 16898613699, 48, 48, 918, 147 },
	["rotate-ccw"] = { 16898613699, 48, 48, 967, 355 },
	["rotate-cw"] = { 16898613699, 48, 48, 869, 453 },
	["rss"] = { 16898613699, 48, 48, 771, 808 },
	["ruler"] = { 16898613699, 48, 48, 710, 869 },
	["save"] = { 16898613699, 48, 48, 918, 453 },
	["scissors"] = { 16898613699, 48, 48, 820, 857 },
	["screen-share"] = { 16898613699, 48, 48, 710, 967 },
	["search"] = { 16898613699, 48, 48, 918, 857 },
	["send"] = { 16898613699, 48, 48, 967, 857 },
	["server"] = { 16898613777, 48, 48, 771, 0 },
	["settings"] = { 16898613777, 48, 48, 771, 257 },
	["settings-2"] = { 16898613777, 48, 48, 0, 771 },
	["share"] = { 16898613777, 48, 48, 514, 771 },
	["share-2"] = { 16898613777, 48, 48, 771, 514 },
	["shield"] = { 16898613777, 48, 48, 869, 0 },
	["shield-off"] = { 16898613777, 48, 48, 820, 514 },
	["shield-check"] = { 16898613777, 48, 48, 820, 257 },
	["shopping-bag"] = { 16898613777, 48, 48, 49, 820 },
	["shopping-cart"] = { 16898613777, 48, 48, 869, 257 },
	["shuffle"] = { 16898613777, 48, 48, 257, 869 },
	["signal"] = { 16898613777, 48, 48, 918, 0 },
	["panel-left"] = { 16898613613, 48, 48, 967, 453 },
	["skip-back"] = { 16898613777, 48, 48, 147, 771 },
	["skip-forward"] = { 16898613777, 48, 48, 98, 820 },
	["skull"] = { 16898613777, 48, 48, 49, 869 },
	["sliders"] = { 16898613777, 48, 48, 404, 771 },
	["sliders-horizontal"] = { 16898613777, 48, 48, 820, 355 },
	["smartphone"] = { 16898613777, 48, 48, 257, 918 },
	["smile"] = { 16898613777, 48, 48, 869, 563 },
	["snowflake"] = { 16898613777, 48, 48, 771, 661 },
	["sparkles"] = { 16898613777, 48, 48, 918, 49 },
	["speaker"] = { 16898613777, 48, 48, 869, 98 },
	["sprout"] = { 16898613777, 48, 48, 918, 306 },
	["square"] = { 16898613777, 48, 48, 869, 710 },
	["star"] = { 16898613777, 48, 48, 967, 147 },
	["stop-circle"] = { 16898613777, 48, 48, 453, 918 },
	["sun"] = { 16898613777, 48, 48, 967, 453 },
	["sunrise"] = { 16898613777, 48, 48, 453, 967 },
	["sunset"] = { 16898613777, 48, 48, 967, 710 },
	["swords"] = { 16898613777, 48, 48, 967, 759 },
	["table"] = { 16898613777, 48, 48, 820, 955 },
	["tablet"] = { 16898613777, 48, 48, 918, 906 },
	["tag"] = { 16898613777, 48, 48, 967, 906 },
	["target"] = { 16898613869, 48, 48, 514, 771 },
	["terminal"] = { 16898613869, 48, 48, 820, 257 },
	["thermometer"] = { 16898613869, 48, 48, 869, 257 },
	["thumbs-down"] = { 16898613869, 48, 48, 820, 306 },
	["thumbs-up"] = { 16898613869, 48, 48, 771, 355 },
	["timer"] = { 16898613869, 48, 48, 918, 0 },
	["toggle-left"] = { 16898613869, 48, 48, 869, 49 },
	["toggle-right"] = { 16898613869, 48, 48, 820, 98 },
	["tornado"] = { 16898613869, 48, 48, 771, 147 },
	["trash"] = { 16898613869, 48, 48, 918, 514 },
	["trash-2"] = { 16898613869, 48, 48, 257, 918 },
	["trending-down"] = { 16898613869, 48, 48, 563, 869 },
	["trending-up"] = { 16898613869, 48, 48, 514, 918 },
	["triangle"] = { 16898613869, 48, 48, 869, 98 },
	["trophy"] = { 16898613869, 48, 48, 820, 147 },
	["truck"] = { 16898613869, 48, 48, 771, 196 },
	["tv"] = { 16898613869, 48, 48, 98, 869 },
	["type"] = { 16898613869, 48, 48, 967, 257 },
	["umbrella"] = { 16898613869, 48, 48, 869, 355 },
	["underline"] = { 16898613869, 48, 48, 820, 404 },
	["undo"] = { 16898613869, 48, 48, 404, 820 },
	["unlink"] = { 16898613869, 48, 48, 869, 612 },
	["unlock"] = { 16898613869, 48, 48, 771, 710 },
	["upload"] = { 16898613869, 48, 48, 612, 869 },
	["user"] = { 16898613869, 48, 48, 661, 869 },
	["user-check"] = { 16898613869, 48, 48, 918, 98 },
	["user-minus"] = { 16898613869, 48, 48, 49, 967 },
	["user-plus"] = { 16898613869, 48, 48, 918, 355 },
	["user-x"] = { 16898613869, 48, 48, 710, 820 },
	["users"] = { 16898613869, 48, 48, 967, 98 },
	["video"] = { 16898613869, 48, 48, 355, 967 },
	["video-off"] = { 16898613869, 48, 48, 404, 918 },
	["voicemail"] = { 16898613869, 48, 48, 869, 710 },
	["volume"] = { 16898613869, 48, 48, 661, 918 },
	["volume-1"] = { 16898613869, 48, 48, 820, 759 },
	["volume-2"] = { 16898613869, 48, 48, 771, 808 },
	["volume-x"] = { 16898613869, 48, 48, 710, 869 },
	["wand-2"] = { 16898613869, 48, 48, 918, 453 },
	["watch"] = { 16898613869, 48, 48, 869, 759 },
	["waves"] = { 16898613869, 48, 48, 820, 808 },
	["webcam"] = { 16898613869, 48, 48, 710, 918 },
	["wifi"] = { 16898613869, 48, 48, 869, 808 },
	["wifi-off"] = { 16898613869, 48, 48, 918, 759 },
	["wind"] = { 16898613869, 48, 48, 820, 857 },
	["wrench"] = { 16898613869, 48, 48, 820, 906 },
	["x"] = { 16898613869, 48, 48, 869, 906 },
	["x-circle"] = { 16898613869, 48, 48, 771, 955 },
	["x-octagon"] = { 16898613869, 48, 48, 967, 808 },
	["x-square"] = { 16898613869, 48, 48, 918, 857 },
	["zap"] = { 16898613869, 48, 48, 918, 906 },
	["zap-off"] = { 16898613869, 48, 48, 967, 857 },
	["zoom-in"] = { 16898613869, 48, 48, 869, 955 },
	["zoom-out"] = { 16898613869, 48, 48, 967, 906 },
}

end)()

--===========================[ Core.Icons ]===========================--
__MODULES["Core.Icons"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Core/Icons.lua
-- Lucide icon lookup + ImageLabel factory.
-- Icon data lives in Core/IconMap.lua (auto-generated, see tools/).
--
--   Icons.Get("home")        -> {id, w, h, ox, oy} or nil
--   Icons.Exists("home")     -> bool
--   Icons:Apply(imageLabel, "home")  -> ok
--   Icons:Create("home", {Size=16, Color=..., Parent=...}) -> ImageLabel
--[[==========================================================================]]

return function(Shared)
	local Icons = {}

	local Data = Shared.Load("Core.IconMap")

	-- Friendly aliases -> canonical lucide names
	local Aliases = {
		edit = "pencil", ["edit-2"] = "pen-line", ["edit-3"] = "square-pen",
		tool = "wrench", sidebar = "panel-left", grid = "grid-2x2",
		["alert"] = "alert-circle", warn = "alert-triangle", error = "alert-octagon",
		gear = "settings", cog2 = "settings-2", exit = "log-out", enter = "log-in",
		remove = "minus", add = "plus", close = "x", tick = "check",
		dot = "circle", colour = "palette", color = "palette",
		controllers = "gamepad-2", game = "gamepad-2", esp = "eye",
	}

	function Icons.Resolve(name)
		if type(name) ~= "string" then
			return nil
		end
		name = name:lower()
		return Aliases[name] or name
	end

	function Icons.Get(name)
		name = Icons.Resolve(name)
		if not name then
			return nil
		end
		return Data[name]
	end

	function Icons.Exists(name)
		return Icons.Get(name) ~= nil
	end

	function Icons.Names()
		local out = {}
		for k in pairs(Data) do
			table.insert(out, k)
		end
		table.sort(out)
		return out
	end

	-- Apply icon rendering properties to an existing ImageLabel/ImageButton.
	function Icons:Apply(imageLabel, name)
		local entry = Icons.Get(name)
		if not entry then
			-- unknown icon: render nothing (transparent) rather than an error
			imageLabel.Image = ""
			return false
		end
		imageLabel.Image = "rbxassetid://" .. tostring(entry[1])
		imageLabel.ImageRectSize = Vector2.new(entry[2], entry[3])
		imageLabel.ImageRectOffset = Vector2.new(entry[4], entry[5])
		imageLabel.ScaleType = Enum.ScaleType.Fit
		imageLabel.BackgroundTransparency = 1
		return true
	end

	-- Create a themed icon ImageLabel.
	-- Icons:Create(name, { Size = 16, Color = Color3|themeKey, Rotation, Parent, ZIndex,
	--                      ImageTransparency, AnchorPoint, Position, LayoutOrder, Name })
	function Icons:Create(name, opts)
		opts = opts or {}
		local size = opts.Size or 16
		local img = Shared.Utility.New("ImageLabel", {
			Name = opts.Name or ("Icon_" .. tostring(name)),
			AnchorPoint = opts.AnchorPoint or Vector2.new(0, 0),
			Position = opts.Position or UDim2.new(),
			Size = typeof(opts.Size) == "UDim2" and opts.Size or UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ImageTransparency = opts.ImageTransparency or 0,
			Rotation = opts.Rotation or 0,
			ZIndex = opts.ZIndex or 2,
			LayoutOrder = opts.LayoutOrder or 0,
			Parent = opts.Parent,
		})
		Icons:Apply(img, name)
		local color = opts.Color
		if color == nil then
			img.ImageColor3 = Shared.Theme:Get("Text")
		elseif type(color) == "string" then
			Shared.Utility.Paint(img, "ImageColor3", color)
		else
			img.ImageColor3 = color
		end
		return img
	end

	-- Convenience: small icon + themed text row, used inside buttons/labels.
	function Icons:IconText(name, text, opts)
		opts = opts or {}
		local row = Shared.Utility.New("Frame", {
			Name = "IconText",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, (opts.Size or 16) + 4),
			Parent = opts.Parent,
		})
		Shared.Utility.ListLayout(row, { Direction = "Horizontal", Padding = 6, Vertical = "Center" })
		Icons:Create(name, { Size = opts.Size or 16, Color = opts.IconColor or "SubText", Parent = row })
		if text and text ~= "" then
			local lab = Shared.Utility.New("TextLabel", {
				Name = "Label",
				BackgroundTransparency = 1,
				Font = opts.Font or Enum.Font.GothamMedium,
				Text = text,
				TextSize = opts.TextSize or 12,
				TextColor3 = Shared.Theme:Get(opts.TextColor or "SubText"),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				Parent = row,
			})
			Shared.Utility.Paint(lab, "TextColor3", opts.TextColor or "SubText")
		end
		return row
	end

	return Icons
end

end)()

--===========================[ Core.Drag ]===========================--
__MODULES["Core.Drag"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Core/Drag.lua
-- Smooth, lerped window/element dragging (mouse + touch). Standard
-- InputBegan/InputChanged model with a RenderStepped smoothing pump.
--
--   local h = Drag:MakeDraggable(handleFrame, targetFrame, {
--       Lerp = 0.35,          -- smoothing factor per frame (0..1]; 1 = none
--       Bounds = true,        -- keep target on screen (default true)
--       OnDragStart = fn, OnDragEnd = fn,
--   })
--   h:Destroy(); h:SetLerp(n); h.Enabled = false
--[[==========================================================================]]

return function(Shared)
	local Drag = {}
	local Services = Shared.Services
	local UIS = Services.UserInputService
	local RunService = Services.RunService
	local Utility = Shared.Utility

	function Drag:MakeDraggable(handle, target, opts)
		opts = opts or {}
		target = target or handle
		local lerp = opts.Lerp or 0.3
		if opts.Bounds == nil then
			opts.Bounds = true
		end

		local state = { Enabled = true }
		local dragging = false
		local dragStart = nil     -- Vector3 from input.Position
		local startPos = nil      -- UDim2 target.Position at drag start
		local goal = nil          -- UDim2 desired Position (offsets computed)

		local function clampGoal(x, y, size)
			if not opts.Bounds then
				return x, y
			end
			local cam = Services.Workspace.CurrentCamera
			local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
			local minX = -size.X + 48
			local maxX = vp.X - 48
			return math.clamp(x, minX, maxX), math.clamp(y, 0, math.max(vp.Y - 48, 60))
		end

		local conns = {}

		local DRAG_THRESHOLD = 3 -- px of movement before a drag begins
		local armed = false

		table.insert(conns, handle.InputBegan:Connect(function(input)
			if not state.Enabled or not Utility.IsClick(input) then
				return
			end
			armed = true
			dragging = false
			dragStart = input.Position
			startPos = target.Position
			local ended
			ended = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					armed = false
					if dragging then
						dragging = false
						if opts.OnDragEnd then
							pcall(opts.OnDragEnd, goal)
						end
					end
					ended:Disconnect()
				end
			end)
			table.insert(conns, ended)
		end))

		table.insert(conns, UIS.InputChanged:Connect(function(input)
			if not armed or not Utility.IsMove(input) then
				return
			end
			local delta = Vector2.new(input.Position.X - dragStart.X, input.Position.Y - dragStart.Y)
			if not dragging then
				if math.abs(delta.X) < DRAG_THRESHOLD and math.abs(delta.Y) < DRAG_THRESHOLD then
					return
				end
				dragging = true
				if opts.OnDragStart then
					pcall(opts.OnDragStart)
				end
			end
			local ox = startPos.X.Offset + delta.X
			local oy = startPos.Y.Offset + delta.Y
			ox, oy = clampGoal(ox, oy, target.AbsoluteSize)
			goal = UDim2.new(startPos.X.Scale, ox, startPos.Y.Scale, oy)
		end))

		-- smoothing pump
		table.insert(conns, RunService.RenderStepped:Connect(function()
			if not goal then
				return
			end
			local cur = target.Position
			local dx = goal.X.Offset - cur.X.Offset
			local dy = goal.Y.Offset - cur.Y.Offset
			if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then
				target.Position = goal
				if not dragging then
					goal = nil
				end
				return
			end
			target.Position = UDim2.new(
				goal.X.Scale, cur.X.Offset + dx * lerp,
				goal.Y.Scale, cur.Y.Offset + dy * lerp)
		end))

		function state:SetLerp(v)
			lerp = math.clamp(v or 0.3, 0.05, 1)
		end

		function state:Destroy()
			dragging = false
			goal = nil
			for _, c in ipairs(conns) do
				pcall(function()
					c:Disconnect()
				end)
			end
		end

		return state
	end

	return Drag
end

end)()

--===========================[ Core.Acrylic ]===========================--
__MODULES["Core.Acrylic"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Core/Acrylic.lua
-- Screen blur ("acrylic") management via Lighting BlurEffect. One BlurEffect
-- instance serves every Tracium window; refcounted so multiple windows don't
-- double-blur or fight.
--
--   Acrylic:Attach()   -> claim   (returns true if blur available)
--   Acrylic:Release()  -> release one claim
--   Acrylic:SetIntensity(n)   0..64 (default 16)
--   Acrylic:SetEnabled(bool)
--[[==========================================================================]]

return function(Shared)
	local Acrylic = {}

	local Lighting = Shared.Services.Lighting
	local blur = nil
	local claims = 0
	local intensity = 16
	local enabled = true

	local function ensure()
		if blur and blur.Parent then
			return blur
		end
		local ok, eff = pcall(function()
			return Shared.Utility.New("BlurEffect", {
				Name = "TraciumAcrylic",
				Size = 0,
				Parent = Lighting,
			})
		end)
		if ok then
			blur = eff
			return blur
		end
		return nil
	end

	local function applyTarget()
		if not blur or not blur.Parent then
			return
		end
		local target = (enabled and claims > 0) and intensity or 0
		Shared.Tween:Play(blur, { Time = 0.4, Style = "Quart", Direction = "Out" }, { Size = target })
	end

	function Acrylic:Attach()
		claims += 1
		if ensure() then
			applyTarget()
			return true
		end
		return false
	end

	function Acrylic:Release()
		claims = math.max(claims - 1, 0)
		applyTarget()
	end

	function Acrylic:IsActive()
		return blur ~= nil and blur.Parent ~= nil and claims > 0 and enabled
	end

	function Acrylic:SetIntensity(n)
		intensity = math.clamp(tonumber(n) or 16, 0, 64)
		applyTarget()
	end

	function Acrylic:GetIntensity()
		return intensity
	end

	function Acrylic:SetEnabled(v)
		enabled = not not v
		if not enabled then
			applyTarget()
		else
			if claims > 0 and ensure() then
				applyTarget()
			end
		end
	end

	function Acrylic:IsEnabled()
		return enabled
	end

	function Acrylic:Destroy()
		claims = 0
		if blur and blur.Parent then
			local b = blur
			Shared.Tween:Play(b, "Fast", { Size = 0 })
			task.delay(0.3, function()
				if b.Parent then
					b:Destroy()
				end
			end)
			blur = nil
		end
	end

	return Acrylic
end

end)()

--===========================[ Core.Tooltip ]===========================--
__MODULES["Core.Tooltip"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Core/Tooltip.lua
-- A single shared tooltip card that follows the mouse after a short hover
-- delay. Themed, animated, clamped to the viewport.
--
--   Tooltip:Attach(guiObject, "Some helpful text")
--   Tooltip:Attach(guiObject, { Title = "Row", Content = "..." })
--   Tooltip:Detach(guiObject)
--   Tooltip:SetEnabled(false)  Tooltip:SetDelay(0.6)
--[[==========================================================================]]

return function(Shared)
	local Tooltip = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local UIS = Shared.Services.UserInputService

	Tooltip.Enabled = true
	Tooltip.Delay = 0.45

	local gui, card, titleLab, contentLab
	local current = nil      -- guiObject currently hovered
	local currentOpts = nil
	local hoverConn, moveConn
	local showToken = 0
	local attached = setmetatable({}, { __mode = "k" })

	local function ensureGui()
		if card and card.Parent then
			return
		end
		gui = Utility.New("ScreenGui", {
			Name = "TraciumTooltip",
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = 1200,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
		Utility.ProtectGui(gui)

		card = Utility.New("Frame", {
			Name = "Card",
			BackgroundColor3 = Theme:Get("Tooltip"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(0, 0, 0, 0),
			Visible = false,
			ZIndex = 10,
			Parent = gui,
		})
		Utility.Paint(card, "BackgroundColor3", "Tooltip")
		Utility.Round(card, 8)
		Utility.Stroke(card, "StrokeHover", 1, 0.4)
		Utility.Pad(card, 8, 6, 8, 6)

		local layout = Utility.ListLayout(card, { Padding = 2 })
		layout.VerticalAlignment = Enum.VerticalAlignment.Top

		titleLab = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.XY,
			Visible = false,
			ZIndex = 11,
			Parent = card,
		})
		Utility.Paint(titleLab, "TextColor3", "Text")

		contentLab = Utility.New("TextLabel", {
			Name = "Content",
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Theme:Get("SubText"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			RichText = false,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(0, 220, 0, 0),
			ZIndex = 11,
			Parent = card,
		})
		Utility.Paint(contentLab, "TextColor3", "SubText")
	end

	local function positionAt(mouse)
		local vp = (Shared.Services.Workspace.CurrentCamera and Shared.Services.Workspace.CurrentCamera.ViewportSize)
			or Vector2.new(1920, 1080)
		local w = math.max(card.AbsoluteSize.X, 60)
		local h = math.max(card.AbsoluteSize.Y, 24)
		local x = mouse.X + 16
		local y = mouse.Y + 18
		if x + w > vp.X - 8 then
			x = mouse.X - w - 14
		end
		if y + h > vp.Y - 8 then
			y = vp.Y - h - 10
		end
		card.Position = UDim2.fromOffset(x, y)
	end

	local function show(opts)
		showToken += 1
		local token = showToken
		local text = type(opts) == "table" and (opts.Content or opts.Text or "") or tostring(opts)
		local title = type(opts) == "table" and opts.Title or nil
		if text == "" and title == nil then
			return
		end
		ensureGui()
		titleLab.Visible = title ~= nil and title ~= ""
		titleLab.Text = title or ""
		contentLab.Text = text
		card.Visible = true
		card.GroupTransparency = nil
		card.BackgroundTransparency = 1
		titleLab.TextTransparency = 1
		contentLab.TextTransparency = 1
		positionAt(Vector2.new(UIS:GetMouseLocation().X, UIS:GetMouseLocation().Y + 36))
		if token ~= showToken then
			return
		end
		Tween:Play(card, "Fast", { BackgroundTransparency = 0.06 })
		Tween:Play(titleLab, "Fast", { TextTransparency = 0 })
		Tween:Play(contentLab, "Fast", { TextTransparency = 0 })
	end

	local function hide()
		showToken += 1
		if not card or not card.Parent or not card.Visible then
			return
		end
		Tween:Play(card, "Fast", { BackgroundTransparency = 1 })
		Tween:Play(titleLab, "Fast", { TextTransparency = 1 })
		Tween:Play(contentLab, "Fast", { TextTransparency = 1 })
		task.delay(0.2, function()
			if card and card.Parent then
				card.Visible = false
			end
		end)
	end

	function Tooltip:Attach(obj, opts)
		if attached[obj] then
			self:Detach(obj)
		end
		local enterConn, leaveConn
		enterConn = obj.MouseEnter:Connect(function()
			if not Tooltip.Enabled then
				return
			end
			current = obj
			currentOpts = opts
			local captured = obj
			task.delay(Tooltip.Delay, function()
				if current == captured and Tooltip.Enabled then
					show(currentOpts)
					if moveConn then
						moveConn:Disconnect()
					end
					moveConn = UIS.InputChanged:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement and card and card.Visible then
							positionAt(Vector2.new(input.Position.X, input.Position.Y + 36))
						end
					end)
				end
			end)
		end)
		leaveConn = obj.MouseLeave:Connect(function()
			if current == obj then
				current = nil
				currentOpts = nil
				hide()
				if moveConn then
					moveConn:Disconnect()
					moveConn = nil
				end
			end
		end)
		attached[obj] = { enterConn, leaveConn }
		return obj
	end

	function Tooltip:Detach(obj)
		local conns = attached[obj]
		if conns then
			for _, c in ipairs(conns) do
				c:Disconnect()
			end
			attached[obj] = nil
		end
		if current == obj then
			current = nil
			hide()
		end
	end

	function Tooltip:SetEnabled(v)
		Tooltip.Enabled = not not v
		if not v then
			hide()
		end
	end

	function Tooltip:IsEnabled()
		return Tooltip.Enabled
	end

	function Tooltip:SetDelay(sec)
		Tooltip.Delay = tonumber(sec) or 0.45
	end

	function Tooltip:Destroy()
		showToken += 1
		if gui then
			gui:Destroy()
			gui, card = nil, nil
		end
	end

	return Tooltip
end

end)()

--===========================[ Core.Theme ]===========================--
__MODULES["Core.Theme"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Core/Theme.lua
-- Central palette registry with animated, live theme switching.
--
--   Theme:Get("Accent")                      -> Color3
--   Theme:Register(inst, "BackgroundColor3", "Card")
--   Theme:OnChange(function() ... end)
--   Theme:Set("Midnight")                    -- animates every registered inst
--   Theme:RegisterCustom("MyTheme", {...})
--
-- Theme keys (every theme defines all of them):
--   Background, BackgroundSecondary, Surface, Inset, Sidebar, Card,
--   CardHover, Element, ElementHover, Stroke, StrokeHover, Divider,
--   Text, SubText, Muted, Accent, Accent2, AccentText, Success, Warning,
--   Danger, Info, Gold, Shadow, Glow, Input, Tooltip
--[[==========================================================================]]

return function(Shared)
	local Theme = {}

	----------------------------------------------------------------------
	-- Palette data. Declared positionally to stay compact; KEYS order is
	-- the single source of truth.
	----------------------------------------------------------------------

	local KEYS = {
		"Background", "BackgroundSecondary", "Surface", "Inset", "Sidebar",
		"Card", "CardHover", "Element", "ElementHover", "Stroke",
		"StrokeHover", "Divider", "Text", "SubText", "Muted",
		"Accent", "Accent2", "AccentText", "Success", "Warning",
		"Danger", "Info", "Gold", "Shadow", "Glow",
		"Input", "Tooltip",
	}
	Theme.Keys = KEYS

	local rgb = Color3.fromRGB
	local function T(name, ...)
		local vals = { ... }
		assert(#vals == #KEYS, ("theme %q has %d values, expected %d"):format(name, #vals, #KEYS))
		local t = { __name = name }
		for i, k in ipairs(KEYS) do
			t[k] = vals[i]
		end
		return t
	end

	local Themes = {}

	-- The flagship dark theme: near-black blues, soft blue/violet accent.
	Themes.Midnight = T("Midnight",
		rgb(11, 12, 18),      -- Background
		rgb(16, 17, 25),      -- BackgroundSecondary
		rgb(19, 21, 30),      -- Surface
		rgb(14, 15, 22),      -- Inset
		rgb(15, 16, 24),      -- Sidebar
		rgb(24, 26, 38),      -- Card
		rgb(31, 34, 48),      -- CardHover
		rgb(26, 28, 40),      -- Element
		rgb(34, 37, 52),      -- ElementHover
		rgb(48, 54, 74),      -- Stroke
		rgb(80, 92, 126),     -- StrokeHover
		rgb(38, 42, 58),      -- Divider
		rgb(240, 243, 252),   -- Text
		rgb(152, 160, 184),   -- SubText
		rgb(104, 112, 136),   -- Muted
		rgb(92, 156, 255),    -- Accent
		rgb(158, 120, 255),   -- Accent2
		rgb(255, 255, 255),   -- AccentText
		rgb(74, 222, 160),    -- Success
		rgb(255, 196, 92),    -- Warning
		rgb(255, 92, 116),    -- Danger
		rgb(92, 200, 255),    -- Info
		rgb(255, 210, 95),    -- Gold
		rgb(0, 0, 0),         -- Shadow
		rgb(92, 156, 255),    -- Glow
		rgb(20, 22, 32),      -- Input
		rgb(24, 26, 38)       -- Tooltip
	)

	-- Teal/cyan on deep blue-black.
	Themes.Aurora = T("Aurora",
		rgb(7, 15, 18), rgb(10, 20, 24), rgb(12, 23, 28), rgb(9, 18, 22), rgb(9, 17, 21),
		rgb(15, 30, 36), rgb(19, 38, 45), rgb(14, 28, 33), rgb(18, 36, 43), rgb(34, 66, 75),
		rgb(51, 96, 108), rgb(27, 52, 60), rgb(230, 250, 247), rgb(134, 176, 178), rgb(76, 112, 118),
		rgb(52, 224, 196), rgb(86, 170, 255), rgb(5, 24, 26), rgb(74, 222, 160),
		rgb(255, 196, 92), rgb(255, 92, 116), rgb(92, 200, 255), rgb(240, 224, 160), rgb(0, 0, 0),
		rgb(52, 224, 196), rgb(11, 25, 30), rgb(15, 30, 36)
	)

	-- Amethyst/violet on dark plum.
	Themes.Violet = T("Violet",
		rgb(13, 10, 21), rgb(17, 13, 27), rgb(20, 15, 32), rgb(15, 11, 25), rgb(16, 12, 26),
		rgb(27, 20, 42), rgb(34, 26, 52), rgb(25, 19, 39), rgb(32, 24, 49), rgb(62, 48, 95),
		rgb(93, 75, 135), rgb(48, 36, 74), rgb(245, 239, 255), rgb(171, 157, 202), rgb(112, 99, 147),
		rgb(181, 124, 255), rgb(255, 122, 196), rgb(255, 255, 255), rgb(74, 222, 160),
		rgb(255, 196, 92), rgb(255, 92, 116), rgb(150, 150, 255), rgb(255, 205, 130), rgb(0, 0, 0),
		rgb(181, 124, 255), rgb(23, 17, 36), rgb(27, 20, 42)
	)

	-- Navy/ocean blues.
	Themes.Ocean = T("Ocean",
		rgb(7, 13, 21), rgb(10, 17, 27), rgb(13, 21, 33), rgb(9, 16, 26), rgb(10, 16, 26),
		rgb(18, 29, 45), rgb(23, 37, 57), rgb(16, 26, 40), rgb(21, 34, 52), rgb(40, 61, 90),
		rgb(61, 90, 128), rgb(30, 47, 70), rgb(234, 243, 252), rgb(142, 160, 184), rgb(92, 108, 132),
		rgb(64, 156, 255), rgb(64, 208, 232), rgb(255, 255, 255), rgb(74, 222, 160),
		rgb(255, 196, 92), rgb(255, 92, 116), rgb(92, 200, 255), rgb(255, 210, 95), rgb(0, 0, 0),
		rgb(64, 156, 255), rgb(13, 24, 38), rgb(18, 29, 45)
	)

	-- Deep red/crimson on near-black.
	Themes.Crimson = T("Crimson",
		rgb(16, 9, 10), rgb(21, 12, 13), rgb(25, 14, 16), rgb(18, 10, 12), rgb(19, 11, 13),
		rgb(33, 18, 21), rgb(41, 23, 27), rgb(30, 17, 20), rgb(38, 21, 25), rgb(74, 41, 47),
		rgb(110, 61, 70), rgb(56, 31, 36), rgb(252, 240, 240), rgb(190, 148, 148), rgb(126, 88, 88),
		rgb(255, 84, 98), rgb(255, 138, 128), rgb(255, 255, 255), rgb(74, 222, 160),
		rgb(255, 196, 92), rgb(255, 92, 116), rgb(140, 180, 255), rgb(255, 205, 110), rgb(0, 0, 0),
		rgb(255, 84, 98), rgb(24, 14, 17), rgb(33, 18, 21)
	)

	-- Deep forest green.
	Themes.Forest = T("Forest",
		rgb(8, 14, 11), rgb(11, 19, 15), rgb(13, 22, 18), rgb(10, 16, 13), rgb(10, 17, 14),
		rgb(17, 29, 23), rgb(21, 36, 29), rgb(15, 26, 21), rgb(19, 33, 26), rgb(37, 62, 50),
		rgb(57, 90, 73), rgb(26, 44, 35), rgb(238, 250, 243), rgb(144, 178, 157), rgb(86, 120, 100),
		rgb(84, 214, 140), rgb(120, 220, 190), rgb(8, 24, 16), rgb(104, 235, 170),
		rgb(255, 196, 92), rgb(255, 92, 116), rgb(120, 200, 160), rgb(232, 220, 150), rgb(0, 0, 0),
		rgb(84, 214, 140), rgb(13, 22, 17), rgb(17, 29, 23)
	)

	-- Warm ember orange on charcoal-brown.
	Themes.Ember = T("Ember",
		rgb(15, 10, 8), rgb(20, 13, 11), rgb(24, 16, 13), rgb(17, 12, 10), rgb(18, 12, 10),
		rgb(31, 21, 17), rgb(39, 27, 22), rgb(28, 19, 16), rgb(36, 25, 20), rgb(72, 48, 38),
		rgb(108, 72, 56), rgb(54, 36, 29), rgb(255, 242, 232), rgb(196, 160, 140), rgb(130, 96, 78),
		rgb(255, 138, 61), rgb(255, 178, 92), rgb(28, 14, 6), rgb(92, 224, 150),
		rgb(255, 196, 92), rgb(255, 92, 116), rgb(255, 170, 110), rgb(255, 205, 100), rgb(0, 0, 0),
		rgb(255, 138, 61), rgb(22, 15, 12), rgb(31, 21, 17)
	)

	-- Pink/rose on charcoal-purple.
	Themes.Rose = T("Rose",
		rgb(15, 9, 13), rgb(20, 12, 18), rgb(24, 15, 22), rgb(17, 11, 16), rgb(18, 11, 17),
		rgb(32, 20, 30), rgb(40, 25, 37), rgb(29, 18, 27), rgb(37, 23, 34), rgb(77, 48, 70),
		rgb(113, 71, 102), rgb(58, 36, 53), rgb(255, 238, 248), rgb(198, 152, 180), rgb(134, 92, 118),
		rgb(255, 105, 160), rgb(255, 145, 200), rgb(255, 255, 255), rgb(74, 222, 160),
		rgb(255, 196, 92), rgb(255, 92, 116), rgb(190, 140, 255), rgb(255, 205, 130), rgb(0, 0, 0),
		rgb(255, 105, 160), rgb(23, 14, 21), rgb(32, 20, 30)
	)

	-- Honey/amber on carbon.
	Themes.Amber = T("Amber",
		rgb(13, 11, 7), rgb(17, 15, 10), rgb(21, 18, 12), rgb(15, 13, 9), rgb(16, 14, 9),
		rgb(27, 24, 15), rgb(34, 30, 19), rgb(24, 21, 14), rgb(31, 28, 17), rgb(66, 58, 36),
		rgb(98, 86, 54), rgb(50, 44, 28), rgb(252, 244, 226), rgb(186, 170, 138), rgb(124, 112, 82),
		rgb(255, 184, 56), rgb(255, 214, 110), rgb(30, 22, 4), rgb(96, 220, 150),
		rgb(255, 205, 92), rgb(255, 92, 116), rgb(150, 190, 255), rgb(255, 220, 120), rgb(0, 0, 0),
		rgb(255, 184, 56), rgb(19, 17, 11), rgb(27, 24, 15)
	)

	-- The classic Dracula palette (official hex values, adapted).
	Themes.Dracula = T("Dracula",
		rgb(30, 31, 41),      -- background #282a36-ish darker
		rgb(34, 35, 46),
		rgb(40, 42, 54),      -- current line
		rgb(33, 34, 44),
		rgb(32, 33, 43),
		rgb(53, 55, 70),      -- #44475a
		rgb(68, 71, 90),
		rgb(48, 50, 64),
		rgb(60, 62, 80),
		rgb(68, 71, 90),
		rgb(98, 103, 130),
		rgb(68, 71, 90),
		rgb(248, 248, 242),   -- foreground
		rgb(186, 189, 206),
		rgb(98, 104, 130),
		rgb(189, 147, 249),   -- purple
		rgb(255, 121, 198),   -- pink
		rgb(40, 42, 54),
		rgb(80, 250, 123),    -- green
		rgb(255, 184, 108),   -- orange
		rgb(255, 85, 85),     -- red
		rgb(139, 233, 253),   -- cyan
		rgb(241, 250, 140),   -- yellow
		rgb(0, 0, 0),
		rgb(189, 147, 249),
		rgb(40, 42, 54),
		rgb(53, 55, 70)
	)

	-- Nord palette (official arctic colors).
	Themes.Nord = T("Nord",
		rgb(36, 41, 51),      -- nord0 adjusted darker
		rgb(41, 46, 57),
		rgb(46, 52, 64),      -- nord0
		rgb(43, 48, 59),
		rgb(43, 48, 59),
		rgb(59, 66, 82),      -- nord1
		rgb(67, 76, 94),      -- nord2
		rgb(54, 61, 76),
		rgb(64, 73, 90),
		rgb(76, 86, 106),     -- nord3
		rgb(101, 113, 135),
		rgb(67, 76, 94),
		rgb(236, 239, 244),   -- nord6
		rgb(216, 222, 233),   -- nord4
		rgb(129, 142, 164),
		rgb(136, 192, 208),   -- nord8 frost
		rgb(129, 161, 193),   -- nord9
		rgb(46, 52, 64),
		rgb(163, 190, 140),   -- nord14
		rgb(235, 203, 139),   -- nord13
		rgb(191, 97, 106),    -- nord11
		rgb(136, 192, 208),
		rgb(208, 135, 112),   -- nord12
		rgb(0, 0, 0),
		rgb(136, 192, 208),
		rgb(46, 52, 64),
		rgb(59, 66, 82)
	)

	-- Neutral cool carbon, monochrome w/ white accent.
	Themes.Carbon = T("Carbon",
		rgb(12, 12, 14), rgb(16, 16, 19), rgb(19, 19, 23), rgb(14, 14, 17), rgb(15, 15, 18),
		rgb(25, 25, 30), rgb(31, 31, 37), rgb(22, 22, 27), rgb(29, 29, 35), rgb(55, 55, 64),
		rgb(85, 85, 98), rgb(43, 43, 51), rgb(244, 244, 248), rgb(160, 160, 175), rgb(105, 105, 122),
		rgb(228, 228, 238), rgb(160, 218, 255), rgb(18, 18, 22), rgb(92, 222, 160),
		rgb(255, 196, 92), rgb(255, 92, 116), rgb(140, 180, 255), rgb(255, 210, 110), rgb(0, 0, 0),
		rgb(228, 228, 238), rgb(17, 17, 20), rgb(25, 25, 30)
	)

	-- Matcha: deep green-grey with lime accent.
	Themes.Matcha = T("Matcha",
		rgb(11, 13, 9), rgb(15, 17, 12), rgb(18, 21, 15), rgb(13, 15, 11), rgb(14, 16, 11),
		rgb(23, 27, 19), rgb(29, 34, 24), rgb(21, 25, 17), rgb(27, 32, 22), rgb(56, 66, 44),
		rgb(84, 98, 66), rgb(42, 50, 33), rgb(240, 248, 228), rgb(172, 186, 150), rgb(112, 126, 92),
		rgb(176, 224, 96), rgb(214, 240, 140), rgb(22, 28, 8), rgb(120, 226, 160),
		rgb(255, 205, 92), rgb(255, 100, 110), rgb(150, 210, 170), rgb(232, 226, 140), rgb(0, 0, 0),
		rgb(176, 224, 96), rgb(16, 19, 13), rgb(23, 27, 19)
	)

	-- Deep space indigo.
	Themes.DeepSpace = T("DeepSpace",
		rgb(9, 10, 22), rgb(13, 14, 28), rgb(16, 17, 34), rgb(11, 12, 26), rgb(12, 13, 27),
		rgb(21, 23, 45), rgb(27, 29, 56), rgb(19, 21, 42), rgb(25, 27, 52), rgb(50, 54, 94),
		rgb(78, 83, 132), rgb(36, 39, 72), rgb(236, 238, 255), rgb(146, 152, 196), rgb(94, 99, 142),
		rgb(103, 118, 255), rgb(80, 210, 255), rgb(255, 255, 255), rgb(94, 230, 175),
		rgb(255, 205, 92), rgb(255, 96, 130), rgb(130, 190, 255), rgb(255, 220, 130), rgb(0, 0, 0),
		rgb(103, 118, 255), rgb(14, 15, 31), rgb(21, 23, 45)
	)

	-- Cocoa: warm brown dark.
	Themes.Cocoa = T("Cocoa",
		rgb(15, 11, 9), rgb(19, 15, 12), rgb(23, 18, 15), rgb(17, 13, 11), rgb(18, 14, 11),
		rgb(29, 23, 19), rgb(36, 29, 24), rgb(26, 21, 17), rgb(33, 27, 22), rgb(66, 52, 42),
		rgb(98, 78, 62), rgb(50, 39, 32), rgb(250, 238, 228), rgb(192, 166, 146), rgb(128, 104, 84),
		rgb(232, 162, 96), rgb(255, 190, 130), rgb(30, 18, 6), rgb(110, 220, 160),
		rgb(255, 196, 92), rgb(255, 92, 116), rgb(180, 190, 255), rgb(255, 214, 120), rgb(0, 0, 0),
		rgb(232, 162, 96), rgb(20, 16, 13), rgb(29, 23, 19)
	)

	-- Snow: the ONE light theme for contrast/demo.
	Themes.Snow = T("Snow",
		rgb(238, 241, 248), rgb(228, 232, 242), rgb(255, 255, 255), rgb(243, 246, 252), rgb(244, 247, 252),
		rgb(255, 255, 255), rgb(240, 244, 251), rgb(252, 253, 255), rgb(238, 242, 250), rgb(205, 213, 230),
		rgb(150, 160, 185), rgb(215, 222, 238), rgb(28, 32, 46), rgb(96, 106, 128), rgb(140, 150, 172),
		rgb(64, 120, 255), rgb(124, 92, 255), rgb(255, 255, 255), rgb(28, 168, 122),
		rgb(210, 140, 40), rgb(220, 64, 90), rgb(40, 150, 220), rgb(190, 150, 30), rgb(160, 172, 196),
		rgb(64, 120, 255), rgb(242, 246, 253), rgb(255, 255, 255)
	)

	Theme.Themes = Themes

-- <<APPEND_LOGIC>>

	----------------------------------------------------------------------
	-- Runtime
	----------------------------------------------------------------------

	Theme.Current = "Midnight"
	Theme.Registered = setmetatable({}, { __mode = "k" }) -- inst -> {prop=key}
	Theme._callbacks = {}

	-- table of the current (possibly mid-transition interpolated) values
	Theme.Values = {}
	for _, k in ipairs(KEYS) do
		Theme.Values[k] = Themes[Theme.Current][k]
	end

	function Theme:Get(key)
		return Theme.Values[key] or Themes[Theme.Current][key] or Color3.new(1, 1, 1)
	end

	function Theme:GetFor(themeName, key)
		local t = Themes[themeName]
		return t and t[key] or Theme:Get(key)
	end

	function Theme:Palette(name)
		return Themes[name]
	end

	function Theme:Names()
		local out = {}
		for n in pairs(Themes) do
			table.insert(out, n)
		end
		table.sort(out)
		return out
	end

	----------------------------------------------------------------------
	-- Registration (Utility.Paint delegates here)
	----------------------------------------------------------------------

	function Theme:Register(inst, prop, key)
		local okSet = pcall(function()
			inst[prop] = Theme:Get(key)
		end)
		if not okSet then
			return nil
		end
		local map = Theme.Registered[inst]
		if not map then
			map = {}
			Theme.Registered[inst] = map
		end
		map[prop] = key
		return inst
	end

	function Theme:Unregister(inst)
		Theme.Registered[inst] = nil
	end

	function Theme:OnChange(fn)
		table.insert(Theme._callbacks, fn)
		return function()
			for i, f in ipairs(Theme._callbacks) do
				if f == fn then
					table.remove(Theme._callbacks, i)
					break
				end
			end
		end
	end

	local function FireChanged(name)
		for _, fn in ipairs(Theme._callbacks) do
			task.spawn(fn, name)
		end
	end

	----------------------------------------------------------------------
	-- Theme switching (animated)
	----------------------------------------------------------------------

	-- Snapshot every registered instance's current color so the tween
	-- starts from where the UI actually is, even mid-animation.
	local function Snapshot()
		local from = {}
		for _, k in ipairs(KEYS) do
			from[k] = Theme.Values[k]
		end
		return from
	end

	local function LerpColor(a, b, t)
		return Color3.new(
			a.R + (b.R - a.R) * t,
			a.G + (b.G - a.G) * t,
			a.B + (b.B - a.B) * t
		)
	end

	local _switchGen = 0

	function Theme:Set(name, animate)
		local target = Themes[name]
		if not target then
			return false
		end
		Theme.Current = name
		_switchGen += 1
		local gen = _switchGen

		if animate == false or not Shared.Tween.Enabled then
			for _, k in ipairs(KEYS) do
				Theme.Values[k] = target[k]
			end
			for inst, map in pairs(Theme.Registered) do
				if inst.Parent then
					for prop, key in pairs(map) do
						pcall(function()
							inst[prop] = target[key]
						end)
					end
				end
			end
			FireChanged(name)
			return true
		end

		local from = Snapshot()
		if Shared.Tween then
			Shared.Tween:Number({
				From = 0, To = 1, Duration = 0.35, Easing = "OutQuart",
				Key = "theme" .. tostring(gen),
				OnUpdate = function(alpha)
					if gen ~= _switchGen then
						return
					end
					for _, k in ipairs(KEYS) do
						local c = LerpColor(from[k], target[k], alpha)
						Theme.Values[k] = c
					end
					for inst, map in pairs(Theme.Registered) do
						if inst.Parent then
							for prop, key in pairs(map) do
								pcall(function()
									inst[prop] = LerpColor(from[key], target[key], alpha)
								end)
							end
						end
					end
				end,
				OnComplete = function()
					if gen == _switchGen then
						FireChanged(name)
					end
				end,
			})
		end
		return true
	end

	----------------------------------------------------------------------
	-- Custom themes (user-registered / ThemeManager addon)
	----------------------------------------------------------------------

	function Theme:RegisterCustom(name, colors)
		assert(type(name) == "string" and #name > 0, "theme name required")
		local base = Theme.Themes[Theme.Current] or Themes.Midnight
		local t = { __name = name, __custom = true }
		for _, k in ipairs(KEYS) do
			local v = colors[k]
			if typeof(v) == "Color3" then
				t[k] = v
			else
				t[k] = base[k] -- fall back to current theme for missing keys
			end
		end
		Themes[name] = t
		return t
	end

	function Theme:RemoveCustom(name)
		if Themes[name] and Themes[name].__custom then
			Themes[name] = nil
			if Theme.Current == name then
				Theme:Set("Midnight", false)
			end
			return true
		end
		return false
	end

	-- Serialize current/custom themes for config persistence
	function Theme:ExportCustom()
		local out = {}
		for name, t in pairs(Themes) do
			if t.__custom then
				local serial = {}
				for _, k in ipairs(KEYS) do
					local c = t[k]
					serial[k] = { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
				end
				out[name] = serial
			end
		end
		return out
	end

	function Theme:ImportCustom(data)
		if type(data) ~= "table" then
			return
		end
		for name, serial in pairs(data) do
			local colors = {}
			for k, rgbArr in pairs(serial) do
				if type(rgbArr) == "table" and rgbArr[1] then
					colors[k] = Color3.fromRGB(
						math.clamp(rgbArr[1] or 0, 0, 255),
						math.clamp(rgbArr[2] or 0, 0, 255),
						math.clamp(rgbArr[3] or 0, 0, 255)
					)
				end
			end
			Theme:RegisterCustom(name, colors)
		end
	end

	return Theme
end

end)()

--===========================[ Core.Notify ]===========================--
__MODULES["Core.Notify"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Core/Notify.lua
-- Toast notification system: stacked cards in any screen corner, typed
-- (Info/Success/Warning/Error), animated, with action buttons, sticky mode,
-- progress bar that pauses on hover.
--
--   local n = Notify:Notify({
--       Title = "Saved", Content = "Config written.", Type = "Success",
--       Duration = 4,                          -- 0 = sticky until dismissed
--       Icon = "check",                         -- optional lucide override
--       Actions = { {Label="Undo", Callback=fn, Style="Primary"} },
--       OnDismiss = fn,
--   })
--   n:Dismiss()
--
--   Notify:SetPosition("TopRight" | "TopLeft" | "BottomRight" | "BottomLeft"
--                      | "TopCenter" | "BottomCenter")
--   Notify:Clear()
--[[==========================================================================]]

return function(Shared)
	local Notify = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	local MAX_VISIBLE = 6
	local DEFAULT_DURATION = 5

	local POSITION = "TopRight"
	local Positions = {
		TopRight     = { anchor = Vector2.new(1, 0), pos = UDim2.new(1, -16, 0, 16), vAlign = Enum.VerticalAlignment.Top,    hAlign = Enum.HorizontalAlignment.Right   },
		TopLeft      = { anchor = Vector2.new(0, 0), pos = UDim2.new(0, 16, 0, 16),  vAlign = Enum.VerticalAlignment.Top,    hAlign = Enum.HorizontalAlignment.Left    },
		BottomRight  = { anchor = Vector2.new(1, 1), pos = UDim2.new(1, -16, 1, -16),vAlign = Enum.VerticalAlignment.Bottom, hAlign = Enum.HorizontalAlignment.Right   },
		BottomLeft   = { anchor = Vector2.new(0, 1), pos = UDim2.new(0, 16, 1, -16), vAlign = Enum.VerticalAlignment.Bottom, hAlign = Enum.HorizontalAlignment.Left    },
		TopCenter    = { anchor = Vector2.new(0.5, 0), pos = UDim2.new(0.5, 0, 0, 16),  vAlign = Enum.VerticalAlignment.Top,    hAlign = Enum.HorizontalAlignment.Center },
		BottomCenter = { anchor = Vector2.new(0.5, 1), pos = UDim2.new(0.5, 0, 1, -16),vAlign = Enum.VerticalAlignment.Bottom, hAlign = Enum.HorizontalAlignment.Center },
	}

	local TypeInfo = {
		Info    = { Color = "Accent",  Icon = "info" },
		Success = { Color = "Success", Icon = "check-circle" },
		Warning = { Color = "Warning", Icon = "alert-triangle" },
		Error   = { Color = "Danger",  Icon = "alert-octagon" },
	}

	local gui = nil
	local stacks = {}       -- position name -> stack frame
	local visible = {}      -- position name -> array of cards
	local queues = {}       -- position name -> array of pending opts
	local active = {}       -- all live cards (for Clear)

	local function ensureGui()
		if gui and gui.Parent then
			return
		end
		gui = Utility.New("ScreenGui", {
			Name = "TraciumNotifications",
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = 1100,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
		Utility.ProtectGui(gui)
		gui.AncestorRemoved:Connect(function(_, parent)
			if parent == nil then
				gui = nil
				stacks = {}
			end
		end)
	end

	local function stackFrame(pos)
		if stacks[pos] and stacks[pos].Parent then
			return stacks[pos]
		end
		ensureGui()
		local def = Positions[pos]
		local holder = Utility.New("Frame", {
			Name = "Stack_" .. pos,
			BackgroundTransparency = 1,
			AnchorPoint = def.anchor,
			Position = def.pos,
			Size = UDim2.new(0, 330, 1, -32),
			Parent = gui,
		})
		local layout = Utility.ListLayout(holder, {
			Padding = 10,
			Horizontal = pos:find("Left") and "Left" or (pos:find("Center") and "Center" or "Right"),
			Vertical = def.vAlign == Enum.VerticalAlignment.Bottom and "Bottom" or "Top",
		})
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		stacks[pos] = holder
		visible[pos] = visible[pos] or {}
		queues[pos] = queues[pos] or {}
		return holder
	end

	local function reflow(pos)
		local holder = stackFrame(pos)
		for i, card in ipairs(visible[pos]) do
			card.LayoutOrder = i
		end
		_ = holder
	end

	local function pumpQueue(pos)
		local holder = stackFrame(pos)
		while #visible[pos] < MAX_VISIBLE and #queues[pos] > 0 do
			local opts = table.remove(queues[pos], 1)
			Notify:_spawn(opts, holder, pos)
		end
		reflow(pos)
	end

	----------------------------------------------------------------------
	-- Card construction
	----------------------------------------------------------------------

	function Notify:_spawn(opts, holder, pos)
		local tinfo = TypeInfo[opts.Type] or TypeInfo.Info
		local fromRight = pos:find("Right") ~= nil

		local card = Utility.New("CanvasGroup", {
			Name = "Notification",
			BackgroundColor3 = Theme:Get("Surface"),
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			GroupTransparency = 1,
			Position = UDim2.new(0, fromRight and 40 or -40, 0, 0),
			Parent = holder,
		})
		Utility.Paint(card, "BackgroundColor3", "Surface")
		Utility.Round(card, 12)
		Utility.Stroke(card, "Stroke", 1, 0.45)

		-- left type bar
		local bar = Utility.New("Frame", {
			Name = "TypeBar",
			BackgroundColor3 = Theme:Get(tinfo.Color),
			BorderSizePixel = 0,
			Size = UDim2.new(0, 3, 1, 0),
			Parent = card,
		})
		Utility.Paint(bar, "BackgroundColor3", tinfo.Color)
		Utility.Round(bar, 2)

		local body = Utility.New("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(1, -10, 0, 0),
			Parent = card,
		})
		Utility.Pad(body, 10, 10, 10, 12)
		Utility.ListLayout(body, { Padding = 4 })

		-- icon + title row
		local titleRow = Utility.New("Frame", {
			Name = "TitleRow",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = body,
		})
		Utility.ListLayout(titleRow, { Direction = "Horizontal", Padding = 8, Vertical = "Top" })

		Icons:Create(opts.Icon or tinfo.Icon, {
			Size = 16, Color = tinfo.Color, Parent = titleRow,
			Name = "TypeIcon",
		})

		local titleLabel = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -46, 0, 0),
			Text = opts.Title or "Notification",
			Parent = titleRow,
		})
		Utility.Paint(titleLabel, "TextColor3", "Text")

		-- close button (dismissible)
		if opts.Dismissible ~= false then
			local close = Utility.New("TextButton", {
				Name = "Close",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(18, 18),
				Text = "",
				AutoButtonColor = false,
				Parent = titleRow,
			})
			local xIcon = Icons:Create("x", { Size = 12, Color = "Muted", Parent = close,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
			close.MouseEnter:Connect(function()
				Tween:Play(xIcon, "Fast", { ImageColor3 = Theme:Get("Text") })
			end)
			close.MouseLeave:Connect(function()
				Tween:Play(xIcon, "Fast", { ImageColor3 = Theme:Get("Muted") })
			end)
			close.MouseButton1Click:Connect(function()
				Notify:_dismiss(card)
			end)
		end

		-- content
		if opts.Content and opts.Content ~= "" then
			local content = Utility.New("TextLabel", {
				Name = "Content",
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextColor3 = Theme:Get("SubText"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, -24, 0, 0),
				Text = opts.Content,
				Parent = body,
			})
			Utility.Paint(content, "TextColor3", "SubText")
		end

		-- actions row
		if type(opts.Actions) == "table" and #opts.Actions > 0 then
			local row = Utility.New("Frame", {
				Name = "Actions",
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				Parent = body,
			})
			Utility.ListLayout(row, { Direction = "Horizontal", Padding = 6 })
			Utility.Pad(row, 0, 4, 0, 0)
			for _, action in ipairs(opts.Actions) do
				local primary = action.Style == "Primary" or action.Primary
				local danger = action.Style == "Danger" or action.Danger
				local btn = Utility.New("TextButton", {
					Name = "Action",
					BackgroundColor3 = primary and Theme:Get("Accent")
						or danger and Theme:Get("Danger") or Theme:Get("Element"),
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
					Text = action.Label or "OK",
					TextColor3 = (primary or danger) and Theme:Get("AccentText") or Theme:Get("Text"),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 0, 24),
					AutoButtonColor = false,
					Parent = row,
				})
				Utility.Paint(btn, "BackgroundColor3",
					primary and "Accent" or danger and "Danger" or "Element")
				Utility.Paint(btn, "TextColor3", (primary or danger) and "AccentText" or "Text")
				Utility.Round(btn, 6)
				Utility.Pad(btn, 10, 0, 10, 0)
				Utility.HoverTint(btn, "BackgroundColor3",
					primary and "Accent" or danger and "Danger" or "Element",
					primary and "Accent" or danger and "Danger" or "ElementHover")
				btn.MouseButton1Click:Connect(function()
					Utility.Ripple(btn)
					if action.Callback then
						pcall(action.Callback)
					end
					if action.DismissOnClick ~= false then
						Notify:_dismiss(card)
					end
				end)
			end
		end

		-- progress bar (non-sticky)
		local fillProgress = nil
		if (opts.Duration or DEFAULT_DURATION) > 0 then
			local track = Utility.New("Frame", {
				Name = "ProgressTrack",
				BackgroundColor3 = Theme:Get("Divider"),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -2),
				Size = UDim2.new(1, 0, 0, 2),
				Parent = card,
			})
			Utility.Paint(track, "BackgroundColor3", "Divider")
			local fill = Utility.New("Frame", {
				Name = "Fill",
				BackgroundColor3 = Theme:Get(tinfo.Color),
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 1, 0),
				Parent = track,
			})
			Utility.Paint(fill, "BackgroundColor3", tinfo.Color)
			local duration = opts.Duration or DEFAULT_DURATION
			local remaining = duration
			local resumedAt = nil
			local function playProgress()
				if fillProgress then
					fillProgress:Cancel()
				end
				if remaining <= 0 then
					return
				end
				resumedAt = tick()
				-- tween from CURRENT fill scale to full over `remaining` seconds
				fillProgress = Shared.Services.TweenService:Create(
					fill,
					TweenInfo.new(remaining, Enum.EasingStyle.Linear),
					{ Size = UDim2.new(1, 0, 1, 0) }
				)
				fillProgress:Play()
			end
			card.MouseEnter:Connect(function()
				if fillProgress and resumedAt then
					remaining = math.max(remaining - (tick() - resumedAt), 0)
					fillProgress:Pause()
				end
			end)
			card.MouseLeave:Connect(function()
				playProgress()
			end)
			playProgress()
			task.delay(duration + 0.1, function()
				if card.Parent then
					Notify:_dismiss(card)
				end
			end)
		end

		-- entrance animation
		Tween:Play(card, "PanelSlide", { Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0 })

		table.insert(visible[pos], card)
		active[card] = pos

		function card.TraciumDismiss()
			Notify:_dismiss(card)
		end

		return card
	end

	function Notify:_dismiss(card)
		if not card or not card.Parent then
			return
		end
		local pos = active[card]
		active[card] = nil
		if pos then
			for i, c in ipairs(visible[pos] or {}) do
				if c == card then
					table.remove(visible[pos], i)
					break
				end
		end
		end
		Tween:Play(card, "Fade", { GroupTransparency = 1 })
		task.delay(0.24, function()
			if card and card.Parent then
				card:Destroy()
			end
			if pos then
				pumpQueue(pos)
			end
		end)
	end

	----------------------------------------------------------------------
	-- Public API
	----------------------------------------------------------------------

	function Notify:Notify(opts)
		if type(opts) == "string" then
			opts = { Title = "Tracium", Content = opts }
		end
		opts = opts or {}
		opts.Type = opts.Type or "Info"
		local pos = opts.Position or POSITION
		local holder = stackFrame(pos)

		local count = #visible[pos]
		if count >= MAX_VISIBLE then
			table.insert(queues[pos], opts)
			return {
				Dismiss = function() end,
				_root = nil,
			}
		end

		local card = self:_spawn(opts, holder, pos)
		reflow(pos)
		local handle = { _root = card }
		function handle:Dismiss()
			Notify:_dismiss(card)
		end
		function handle:Update(newOpts)
			if not card or not card.Parent then
				return
			end
			if newOpts.Title then
				card.Body.TitleRow.Title.Text = newOpts.Title
			end
			if newOpts.Content and card.Body:FindFirstChild("Content") then
				card.Body.Content.Text = newOpts.Content
			end
		end
		return handle
	end

	function Notify:SetPosition(pos)
		if Positions[pos] then
			POSITION = pos
		end
	end

	function Notify:GetPosition()
		return POSITION
	end

	function Notify:Clear()
		for card in pairs(active) do
			Notify:_dismiss(card)
		end
	end

	function Notify:ClearAll()
		Notify:Clear()
	end

	-- allow Notify({...}) shorthand
	return setmetatable(Notify, {
		__call = function(_, opts)
			return Notify:Notify(opts)
		end,
	})
end

end)()

--===========================[ Core.Config ]===========================--
__MODULES["Core.Config"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Core/Config.lua
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

end)()

--===========================[ Components.Button ]===========================--
__MODULES["Components.Button"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Components/Button.lua
-- A clickable row element. Supports subtitle, icon, hold-to-confirm,
-- variants (default/danger/success), and a loading state.
--
--   Section:Button({ Title="Collect", Callback=fn, ... })
--   handle:Fire()   -- programmatic click
--[[==========================================================================]]

return function(Shared)
	local Button = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	local VARIANT = {
		Default = { Color = "Accent", Text = "AccentText" },
		Danger = { Color = "Danger", Text = "AccentText" },
		Success = { Color = "Success", Text = "AccentText" },
		Muted = { Color = "Element", Text = "Text" },
	}

	function Button.New(scope, opts)
		opts = opts or {}
		local variant = VARIANT[opts.Variant] or VARIANT.Default

		local root = Utility.New("Frame", {
			Name = "Button_" .. (opts.Title or "btn"),
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Card")
		Utility.Round(root, 8)
		Utility.Stroke(root, "Stroke", 1, 0.6)
		Utility.Pad(root, 10, 8, 10, 8)

		local clickArea = Utility.New("TextButton", {
			Name = "Hitbox",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 3,
			Parent = root,
		})

		local inner = Utility.New("Frame", {
			Name = "Inner",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.ListLayout(inner, { Padding = 2 })

		local titleRow = Utility.New("Frame", {
			Name = "TitleRow",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Parent = inner,
		})
		Utility.ListLayout(titleRow, { Direction = "Horizontal", Padding = 6, Vertical = "Center" })

		if opts.Icon then
			Icons:Create(opts.Icon, { Size = 14, Color = "SubText", Parent = titleRow })
		end

		local titleLabel = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Text = opts.Title or "Button",
			Parent = titleRow,
		})
		Utility.Paint(titleLabel, "TextColor3", "Text")

		-- right-aligned "run" chip
		local chip = Utility.New("TextLabel", {
			Name = "Chip",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 18),
			BackgroundColor3 = Theme:Get(variant.Color),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = Theme:Get(variant.Text),
			Text = " " .. (opts.Chip or "Run") .. " ",
			Parent = root,
		})
		Utility.Paint(chip, "BackgroundColor3", variant.Color)
		Utility.Paint(chip, "TextColor3", variant.Text)
		Utility.Round(chip, 4)

		-- description
		if opts.Description and opts.Description ~= "" then
			local desc = Utility.New("TextLabel", {
				Name = "Desc",
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 11,
				TextColor3 = Theme:Get("SubText"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				Text = opts.Description,
				Parent = inner,
			})
			Utility.Paint(desc, "TextColor3", "SubText")
		end

		-- interactive states
		local hovered = false
		clickArea.MouseEnter:Connect(function()
			hovered = true
			Tween:Play(root, "Fast", { BackgroundColor3 = Theme:Get("CardHover") })
		end)
		clickArea.MouseLeave:Connect(function()
			hovered = false
			Tween:Play(root, "Fast", { BackgroundColor3 = Theme:Get("Card") })
		end)

		local respPress, respRelease
		clickArea.MouseButton1Down:Connect(function()
			respPress = Tween:Play(chip, "Micro", { BackgroundTransparency = 0.3 })
		end)
		clickArea.MouseButton1Up:Connect(function()
			if respPress then
				Tween:Play(chip, "Micro", { BackgroundTransparency = 0 })
			end
		end)

		local busy = false
		local function fire()
			if busy then
				return
			end
			if opts.HoldToConfirm then
				-- Double-click within 600ms required
				if root:GetAttribute("Armed") and (tick() - root:GetAttribute("ArmTime")) < 0.6 then
					root:SetAttribute("Armed", false)
					chip.Text = " " .. (opts.Chip or "Run") .. " "
				else
					root:SetAttribute("Armed", true)
					root:SetAttribute("ArmTime", tick())
					chip.Text = " Confirm? "
					Tween:Play(chip, "Fast", { BackgroundColor3 = Theme:Get("Warning") })
					task.delay(0.6, function()
						if root.Parent and root:GetAttribute("Armed") then
							root:SetAttribute("Armed", false)
							chip.Text = " " .. (opts.Chip or "Run") .. " "
							Tween:Play(chip, "Fast", { BackgroundColor3 = Theme:Get(variant.Color) })
						end
					end)
					return
				end
			end
			Utility.Ripple(root)
			if opts.LoadingLabel then
				busy = true
				local old = chip.Text
				chip.Text = " " .. opts.LoadingLabel .. " "
				task.delay(0.8, function()
					if chip.Parent then
						chip.Text = old
					end
					busy = false
				end)
			end
			if opts.Callback then
				local ok, err = pcall(opts.Callback)
				if not ok then
					Shared.Notify:Notify({
						Title = "Button Error",
						Content = tostring(err),
						Type = "Error",
						Duration = 4,
					})
				end
			end
		end
		clickArea.MouseButton1Click:Connect(fire)
		_ = respRelease

		if opts.Tooltip then
			Shared.Tooltip:Attach(root, opts.Tooltip)
		end

		local self = {
			Type = "Button",
			Root = root,
			Flag = opts.Flag,
			Options = opts,
			Value = false,
		}

		function self:Fire()
			fire()
		end

		function self:SetTitle(t)
			titleLabel.Text = t
		end

		function self:SetChip(text)
			chip.Text = " " .. tostring(text) .. " "
		end

		function self:Set(text) -- generic alias for SetTitle
			self:SetTitle(text)
		end

		function self:Get()
			return false
		end

		function self:Destroy()
			root:Destroy()
		end

		return self
	end

	return Button
end

end)()

--===========================[ Components.Toggle ]===========================--
__MODULES["Components.Toggle"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Components/Toggle.lua
-- Animated switch (or checkbox) with optional description, tooltip,
-- and attachable mini-controls via :AddKeybind / :AddColorPicker chips.
--
--   local t = Section:Toggle({ Title="Aimbot", Default=false, Flag="Aimbot",
--                              Mode="Toggle", Callback=function(v) end })
--   t:Set(true);  t:AddKeybind({ Flag="AimbotKey" })  t:AddColorPicker{...}
--[[==========================================================================]]

return function(Shared)
	local Toggle = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	function Toggle.New(scope, opts)
		opts = opts or {}
		local value = opts.Default == true
		local listeners = {}

		local root = Utility.New("Frame", {
			Name = "Toggle_" .. (opts.Title or "?"),
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Card")
		Utility.Round(root, 8)
		Utility.Stroke(root, "Stroke", 1, 0.6)

		local body = Utility.New("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.Pad(body, 10, 8, 10, 8)
		Utility.ListLayout(body, { Padding = 2 })

		local titleRow = Utility.New("Frame", {
			Name = "Row",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = body,
		})
		Utility.ListLayout(titleRow, { Direction = "Horizontal", Padding = 6, Vertical = "Center" })

		local titleLabel = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -110, 0, 0),
			Text = opts.Title or "Toggle",
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = titleRow,
		})
		Utility.Paint(titleLabel, "TextColor3", "Text")

		if opts.Description and opts.Description ~= "" then
			local desc = Utility.New("TextLabel", {
				Name = "Desc",
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 11,
				TextColor3 = Theme:Get("SubText"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				Text = opts.Description,
				Parent = body,
			})
			Utility.Paint(desc, "TextColor3", "SubText")
		end

		-- sub-control chips live right of the title row, before the switch
		local chips = Utility.New("Frame", {
			Name = "Chips",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 20),
			LayoutOrder = 2,
			Parent = titleRow,
		})
		Utility.ListLayout(chips, { Direction = "Horizontal", Padding = 4, Horizontal = "Right", Vertical = "Center" })

		------------------------------------------------------------------
		-- Switch control
		------------------------------------------------------------------
		local switch = Utility.New("TextButton", {
			Name = "Switch",
			BackgroundColor3 = value and Theme:Get("Accent") or Theme:Get("Element"),
			Size = UDim2.new(0, 38, 0, 20),
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = 3,
			Parent = titleRow,
		})
		Utility.Round(switch, 10)
		local switchStroke = Utility.Stroke(switch, value and "Accent" or "StrokeHover", 1, 0.4)

		local knob = Utility.New("Frame", {
			Name = "Knob",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Position = value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.new(0, 14, 0, 14),
			Parent = switch,
		})
		Utility.Round(knob, 7)
		Utility.Gradient(knob, Color3.new(1, 1, 1), Color3.fromRGB(225, 228, 238), 90)

		local function paintSwitch(v, animate)
			local trackColor = v and Theme:Get("Accent") or Theme:Get("Element")
			local strokeKey = v and "Accent" or "StrokeHover"
			if animate then
				Tween:Play(switch, "Fast", { BackgroundColor3 = trackColor })
				Tween:Play(knob, "Spring", { Position = v and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
				Tween:Play(knob, "Fast", { Size = v and UDim2.new(0, 16, 0, 16) or UDim2.new(0, 14, 0, 14) })
			else
				switch.BackgroundColor3 = trackColor
				knob.Position = v and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
			end
			Utility.Paint(switch, "BackgroundColor3", v and "Accent" or "Element")
			Utility.Paint(switchStroke, "Color", strokeKey)
		end

		local self = {
			Type = "Toggle",
			Root = root,
			Flag = opts.Flag,
			Options = opts,
			Value = value,
		}

		local function setInternal(v, silent, animate)
			value = not not v
			self.Value = value
			paintSwitch(value, animate ~= false)
			if self.Flag then
				Shared.Config:NotifyChange(self.Flag, value)
			end
			if not silent then
				if opts.Callback then
					task.spawn(function()
						local ok, err = pcall(opts.Callback, value)
						if not ok then
							Shared.Notify:Notify({ Title = "Toggle Error", Content = tostring(err), Type = "Error" })
						end
					end)
				end
				for _, fn in ipairs(listeners) do
					task.spawn(fn, value)
				end
			end
		end

		switch.MouseButton1Click:Connect(function()
			Utility.Ripple(switch)
			setInternal(not value)
		end)

		-- whole row clicks (except when clicking a chip)
		local rowBtn = Utility.New("TextButton", {
			Name = "RowClick",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -60, 1, 0),
			Text = "",
			ZIndex = 1,
			Parent = root,
		})
		titleRow.ZIndex = 3
		switch.ZIndex = 4
		rowBtn.MouseButton1Click:Connect(function()
			setInternal(not value)
		end)
		rowBtn.MouseEnter:Connect(function()
			Tween:Play(root, "Fast", { BackgroundColor3 = Theme:Get("CardHover") })
		end)
		rowBtn.MouseLeave:Connect(function()
			Tween:Play(root, "Fast", { BackgroundColor3 = Theme:Get("Card") })
		end)

		function self:Set(v)
			setInternal(v, false, true)
		end

		function self:SetQuiet(v)
			setInternal(v, true, false)
		end

		function self:ConfigSet(v)
			setInternal(v == true, true, false)
		end

		function self:Get()
			return value
		end

		function self:OnChanged(fn)
			table.insert(listeners, fn)
			return function()
				for i, f in ipairs(listeners) do
					if f == fn then
						table.remove(listeners, i)
						break
					end
				end
			end
		end

		-- keybind mini-chip below the row (Linoria style)
		function self:AddKeybind(kopts)
			kopts = kopts or {}
			kopts.Title = kopts.Title or (opts.Title .. " Key")
			kopts.Mode = kopts.Mode or "Toggle"
			kopts._embeddedToggle = self
			local kb = Shared.Components.Keybind.NewEmbedding(scope, kopts, chips)
			if kopts.Flag then
				Shared.Config:Register(kb)
			end
			return kb
		end

		function self:AddColorPicker(copts)
			copts = copts or {}
			copts.Title = copts.Title or (opts.Title .. " Color")
			local cp = Shared.Components.ColorPicker.NewEmbedding(scope, copts, chips)
			if copts.Flag then
				Shared.Config:Register(cp)
			end
			return cp
		end

		if opts.Tooltip then
			Shared.Tooltip:Attach(root, opts.Tooltip)
		end

		-- config bootstrap
		if self.Flag then
			Shared.Config:Register(self)
		end

		function self:Destroy()
			root:Destroy()
			if self.Flag then
				Shared.Config:Unregister(self.Flag)
			end
		end

		return self
	end

	return Toggle
end

end)()

--===========================[ Components.Slider ]===========================--
__MODULES["Components.Slider"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Components/Slider.lua
-- Value slider with drag, wheel-stepping, editable value chip, optional
-- min/max labels and suffix. Fires live during drag.
--
--   local s = Section:Slider({ Title="Speed", Min=0, Max=500, Default=16,
--       Increment=1, Suffix=" studs", Flag="Speed", Callback=fn })
--   s:Set(50)
--[[==========================================================================]]

return function(Shared)
	local Slider = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local UIS = Shared.Services.UserInputService

	local function decimalsFor(increment)
		increment = increment or 1
		if increment >= 1 then
			return 0
		end
		local s = tostring(increment)
		local frac = s:match("%.(%d+)$")
		return frac and #frac or 2
	end

	function Slider.New(scope, opts)
		opts = opts or {}
		local min = tonumber(opts.Min) or 0
		local max = tonumber(opts.Max) or 100
		if max <= min then
			max = min + 1
		end
		local decimals = opts.Decimals or decimalsFor(opts.Increment)
		local increment = opts.Increment or (decimals > 0 and 0.1 or 1)
		local suffix = opts.Suffix or ""
		local prefix = opts.Prefix or ""

		local value = math.clamp(tonumber(opts.Default) or min, min, max)

		local root = Utility.New("Frame", {
			Name = "Slider_" .. (opts.Title or "?"),
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Card")
		Utility.Round(root, 8)
		Utility.Stroke(root, "Stroke", 1, 0.6)
		Utility.Pad(root, 10, 8, 10, 10)

		local col = Utility.New("Frame", {
			Name = "Col",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.ListLayout(col, { Padding = 6 })

		-- header row: title + value chip
		local header = Utility.New("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Parent = col,
		})

		local titleLabel = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -90, 1, 0),
			Text = opts.Title or "Slider",
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = header,
		})
		Utility.Paint(titleLabel, "TextColor3", "Text")

		local function format(v)
			return prefix .. string.format("%." .. decimals .. "f", v) .. suffix
		end

		local chip = Utility.New("TextButton", {
			Name = "ValueChip",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 18),
			BackgroundColor3 = Theme:Get("Input"),
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Theme:Get("Accent"),
			Text = format(value),
			AutoButtonColor = false,
			Parent = header,
		})
		Utility.Paint(chip, "BackgroundColor3", "Input")
		Utility.Paint(chip, "TextColor3", "Accent")
		Utility.Round(chip, 5)
		Utility.Pad(chip, 6, 0, 6, 0)

		if opts.Description and opts.Description ~= "" then
			local desc = Utility.New("TextLabel", {
				Name = "Desc",
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 11,
				TextColor3 = Theme:Get("SubText"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				Text = opts.Description,
				Parent = col,
			})
			Utility.Paint(desc, "TextColor3", "SubText")
		end

		------------------------------------------------------------------
		-- Track
		------------------------------------------------------------------
		local track = Utility.New("TextButton", {
			Name = "Track",
			BackgroundColor3 = Theme:Get("Element"),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 10),
			Text = "",
			AutoButtonColor = false,
			Parent = col,
		})
		Utility.Paint(track, "BackgroundColor3", "Element")
		Utility.Round(track, 5)

		local fill = Utility.New("Frame", {
			Name = "Fill",
			BackgroundColor3 = Theme:Get("Accent"),
			BorderSizePixel = 0,
			Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
			Parent = track,
		})
		Utility.Round(fill, 5)
		Utility.Gradient(fill, "Accent", "Accent2", 0)

		local knob = Utility.New("Frame", {
			Name = "Knob",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			ZIndex = 3,
			Parent = track,
		})
		Utility.Round(knob, 7)
		Utility.Stroke(knob, "Accent", 2, 0.2)

		-- min/max labels
		if opts.ShowRange then
			local rangeRow = Utility.New("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 12),
				Parent = col,
			})
			local function rlbl(text, right)
				local l = Utility.New("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					TextSize = 10,
					TextColor3 = Theme:Get("Muted"),
					TextXAlignment = right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
					Size = UDim2.new(0.5, 0, 1, 0),
					Position = right and UDim2.new(0.5, 0, 0, 0) or UDim2.new(0, 0, 0, 0),
					Text = text,
					Parent = rangeRow,
				})
				Utility.Paint(l, "TextColor3", "Muted")
			end
			rlbl(prefix .. tostring(min) .. suffix)
			rlbl(prefix .. tostring(max) .. suffix, true)
		end

		------------------------------------------------------------------
		-- Value logic
		------------------------------------------------------------------
		local listeners = {}
		local dragging = false
		local self = {
			Type = "Slider",
			Root = root,
			Flag = opts.Flag,
			Options = opts,
			Value = value,
		}

		local function snap(v)
			v = math.clamp(v, min, max)
			if increment and increment > 0 then
				v = min + math.floor((v - min) / increment + 0.5) * increment
			end
			v = Utility.RoundNum(v, decimals)
			return v
		end

		local function applyVisual(v, animate)
			local alpha = (v - min) / (max - min)
			if animate then
				Tween:Play(fill, "Micro", { Size = UDim2.new(alpha, 0, 1, 0) })
				Tween:Play(knob, "Micro", { Position = UDim2.new(alpha, 0, 0.5, 0) })
			else
				fill.Size = UDim2.new(alpha, 0, 1, 0)
				knob.Position = UDim2.new(alpha, 0, 0.5, 0)
			end
		end

		local function set(v, silent)
			v = snap(v)
			if v == self.Value then
				applyVisual(v, false)
				chip.Text = format(v)
				return
			end
			self.Value = v
			value = v
			applyVisual(v, true)
			chip.Text = format(v)
			if self.Flag then
				Shared.Config:NotifyChange(self.Flag, v)
			end
			if not silent then
				if opts.Callback then
					task.spawn(function()
						pcall(opts.Callback, v)
					end)
				end
				for _, fn in ipairs(listeners) do
					task.spawn(fn, v)
				end
			end
		end

		local function fromInput(x)
			local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			set(min + (max - min) * rel)
		end

		track.InputBegan:Connect(function(input)
			if not Utility.IsClick(input) then
				return
			end
			dragging = true
			Tween:Play(knob, "Fast", { Size = UDim2.fromOffset(17, 17) })
			fromInput(input.Position.X)
		end)
		UIS.InputChanged:Connect(function(input)
			if dragging and Utility.IsMove(input) then
				fromInput(input.Position.X)
			end
		end)
		UIS.InputEnded:Connect(function(input)
			if Utility.IsClick(input) and dragging then
				dragging = false
				Tween:Play(knob, "Fast", { Size = UDim2.fromOffset(14, 14) })
			end
		end)

		-- mouse wheel adjusts by increment
		track.MouseWheelForward:Connect(function()
			set(self.Value + increment)
		end)
		track.MouseWheelBackward:Connect(function()
			set(self.Value - increment)
		end)

		-- editable chip: click to type exact value
		chip.MouseButton1Click:Connect(function()
			local box = Utility.New("TextBox", {
				Name = "Edit",
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextColor3 = Theme:Get("Accent"),
				Text = tostring(self.Value),
				Size = UDim2.new(1, 0, 1, 0),
				ClearTextOnFocus = false,
				Parent = chip,
			})
			box.Text = tostring(self.Value)
			box:CaptureFocus()
			box:SelectAll()
			local done = false
			box.FocusLost:Connect(function(enter)
				if done then
					return
				end
				done = true
				local n = tonumber(box.Text)
				if enter and n then
					set(n)
				end
				box:Destroy()
				chip.Text = format(self.Value)
			end)
		end)

		------------------------------------------------------------------
		-- Public
		------------------------------------------------------------------
		function self:Set(v)
			set(v, false)
		end

		function self:SetQuiet(v)
			set(v, true)
		end

		function self:ConfigSet(v)
			set(tonumber(v) or min, true)
		end

		function self:Get()
			return self.Value
		end

		function self:SetMinMax(nmin, nmax)
			min = tonumber(nmin) or min
			max = tonumber(nmax) or max
			if max <= min then
				max = min + 1
			end
			set(self.Value)
		end

		function self:OnChanged(fn)
			table.insert(listeners, fn)
		end

		if opts.Tooltip then
			Shared.Tooltip:Attach(root, opts.Tooltip)
		end

		-- config
		if self.Flag then
			Shared.Config:Register(self)
		end
		-- paint initial
		applyVisual(self.Value, false)

		function self:Destroy()
			root:Destroy()
			if self.Flag then
				Shared.Config:Unregister(self.Flag)
			end
		end

		return self
	end

	return Slider
end

end)()

--===========================[ Components.Dropdown ]===========================--
__MODULES["Components.Dropdown"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Components/Dropdown.lua
-- Select one (or many, opts.Multi) values from a popup list. Searchable.
--
--   Section:Dropdown({ Title="Target", Values={"All","Closest","LowHP"},
--       Default="All", Multi=false, Flag="Target", Callback=fn })
--   handle:Refresh({...})  handle:Set("Closest")  handle:Get()
--[[==========================================================================]]

return function(Shared)
	local Dropdown = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	function Dropdown.New(scope, opts)
		opts = opts or {}
		local values = opts.Values or opts.Options or {}
		local multi = opts.Multi == true
		local selected -- string (single) | set table value->true (multi)

		if multi then
			selected = {}
			if type(opts.Default) == "table" then
				for _, v in ipairs(opts.Default) do
					selected[v] = true
				end
			end
		else
			selected = opts.Default
			if selected == nil then
				selected = opts.DefaultIndex and values[opts.DefaultIndex] or values[1]
			end
		end

		------------------------------------------------------------------
		-- Row card
		------------------------------------------------------------------
		local root = Utility.New("Frame", {
			Name = "Dropdown_" .. (opts.Title or "?"),
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Card")
		Utility.Round(root, 8)
		Utility.Stroke(root, "Stroke", 1, 0.6)
		Utility.Pad(root, 10, 8, 10, 8)

		local col = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.ListLayout(col, { Padding = 6 })

		local header = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = col,
		})
		Utility.ListLayout(header, { Direction = "Horizontal", Padding = 6, Vertical = "Center" })

		local title = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -140, 0, 18),
			Text = opts.Title or "Dropdown",
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = header,
		})
		Utility.Paint(title, "TextColor3", "Text")

		------------------------------------------------------------------
		-- Button
		------------------------------------------------------------------
		local btn = Utility.New("TextButton", {
			Name = "Button",
			BackgroundColor3 = Theme:Get("Input"),
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Theme:Get("Text"),
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(0, 132, 0, 24),
			Parent = header,
		})
		Utility.Paint(btn, "BackgroundColor3", "Input")
		Utility.Paint(btn, "TextColor3", "Text")
		Utility.Round(btn, 6)
		Utility.Stroke(btn, "Stroke", 1, 0.5)
		Utility.Pad(btn, 8, 0, 24, 0)

		local btnText = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 1, 0),
			Text = "(none)",
			Parent = btn,
		})
		Utility.Paint(btnText, "TextColor3", "Text")

		local chevron = Icons:Create("chevron-down", {
			Size = 12, Color = "Muted",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 4, 0.5, 0),
			Parent = btn, Name = "Chevron",
		})

		------------------------------------------------------------------
		-- Popup (in window popup layer)
		------------------------------------------------------------------
		local popup, searchBox, listFrame
		local isOpen = false
		local closePopup, openPopup

		local function displayText()
			if multi then
				local names = {}
				for _, v in ipairs(values) do
					if selected[v] then
						table.insert(names, tostring(v))
					end
				end
				if #names == 0 then
					return "(none)"
				end
				local txt = table.concat(names, ", ")
				if #txt > 22 then
					return #names .. " selected"
				end
				return txt
			end
			return selected ~= nil and tostring(selected) or "(none)"
		end

		local function refreshButton()
			btnText.Text = displayText()
		end

		local listeners = {}
		local function fire()
			if opts.Callback then
				task.spawn(function()
					if multi then
						local arr = {}
						for _, v in ipairs(values) do
							if selected[v] then
								table.insert(arr, v)
							end
						end
						pcall(opts.Callback, arr)
					else
						pcall(opts.Callback, selected)
					end
				end)
			end
			for _, fn in ipairs(listeners) do
				task.spawn(fn)
			end
		end

		local function notifyFlag()
			if not opts.Flag then
				return
			end
			if multi then
				local arr = {}
				for _, v in ipairs(values) do
					if selected[v] then
						table.insert(arr, v)
					end
				end
				Shared.Config:NotifyChange(opts.Flag, arr)
			else
				Shared.Config:NotifyChange(opts.Flag, selected)
			end
		end

		local function buildItems(filter)
			for _, c in ipairs(listFrame:GetChildren()) do
				if c:IsA("TextButton") then
					c:Destroy()
				end
			end
			local order = 0
			for _, v in ipairs(values) do
				local text = tostring(v)
				if filter == "" or text:lower():find(filter, 1, true) then
					order += 1
					local isSel = multi and selected[v] or (selected == v)
					local item = Utility.New("TextButton", {
						Name = "Opt_" .. text,
						BackgroundColor3 = isSel and Theme:Get("Element") or Theme:Get("Card"),
						Font = Enum.Font.GothamMedium,
						TextSize = 11,
						TextColor3 = isSel and Theme:Get("Text") or Theme:Get("SubText"),
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = "  " .. text,
						Size = UDim2.new(1, 0, 0, 22),
						AutoButtonColor = false,
						LayoutOrder = order,
						Parent = listFrame,
					})
					Utility.Paint(item, "BackgroundColor3", isSel and "Element" or "Card")
					Utility.Paint(item, "TextColor3", isSel and "Text" or "SubText")
					Utility.Round(item, 5)

					if multi then
						local check = Icons:Create(isSel and "check-square" or "square", {
							Size = 12,
							Color = isSel and "Accent" or "Muted",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -6, 0.5, 0),
							Parent = item,
						})
						item:SetAttribute("CheckIcon", true)
						_ = check
					elseif isSel then
						Icons:Create("check", {
							Size = 12, Color = "Accent",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -6, 0.5, 0),
							Parent = item,
						})
					end

					item.MouseEnter:Connect(function()
						Tween:Play(item, "Fast", { BackgroundColor3 = Theme:Get("ElementHover") })
					end)
					item.MouseLeave:Connect(function()
						local s = multi and selected[v] or (selected == v)
						Tween:Play(item, "Fast", { BackgroundColor3 = Theme:Get(s and "Element" or "Card") })
					end)
					item.MouseButton1Click:Connect(function()
						if multi then
							selected[v] = not selected[v] or nil
							if selected[v] == false then
								selected[v] = nil
							end
							refreshButton()
							notifyFlag()
							fire()
							buildItems(searchBox and searchBox.Text or "")
						else
							selected = v
							refreshButton()
							notifyFlag()
							fire()
							closePopup()
						end
					end)
				end
			end
		end

		openPopup = function()
			if isOpen or not scope.Window then
				return
			end
			isOpen = true
			Tween:Play(chevron, "Fast", { Rotation = 180 })

			popup = Utility.New("Frame", {
				Name = "DropdownPopup",
				BackgroundColor3 = Theme:Get("Surface"),
				BorderSizePixel = 0,
				Size = UDim2.new(0, btn.AbsoluteSize.X, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				GroupTransparency = 0,
				ClipsDescendants = true,
				ZIndex = 60,
				Parent = scope.Window.PopupLayer,
			})
			Utility.Paint(popup, "BackgroundColor3", "Surface")
			Utility.Round(popup, 8)
			Utility.Stroke(popup, "StrokeHover", 1, 0.3)
			Utility.Pad(popup, 6, 6, 6, 6)

			local pcol = Utility.New("Frame", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				Parent = popup,
			})
			Utility.ListLayout(pcol, { Padding = 4 })

			-- search
			local searchable = opts.Searchable or #values > 8
			if searchable then
				local searchWrap = Utility.New("Frame", {
					BackgroundColor3 = Theme:Get("Input"),
					Size = UDim2.new(1, 0, 0, 24),
					Parent = pcol,
				})
				Utility.Paint(searchWrap, "BackgroundColor3", "Input")
				Utility.Round(searchWrap, 6)
				searchBox = Utility.New("TextBox", {
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					TextSize = 11,
					TextColor3 = Theme:Get("Text"),
					PlaceholderText = "Search...",
					PlaceholderColor3 = Theme:Get("Muted"),
					Text = "",
					Size = UDim2.new(1, -26, 1, 0),
					Position = UDim2.new(0, 8, 0, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = searchWrap,
				})
				Utility.Paint(searchBox, "TextColor3", "Text")
				searchBox:GetPropertyChangedSignal("Text"):Connect(function()
					buildItems(searchBox.Text:lower())
				end)
			end

			local maxItems = math.min(#values, 7)
			listFrame = Utility.New("ScrollingFrame", {
				Name = "List",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, maxItems * 26),
				CanvasSize = UDim2.new(),
				ScrollBarThickness = 2,
				ScrollBarImageColor3 = Theme:Get("Muted"),
				Parent = pcol,
			})
			Utility.Paint(listFrame, "ScrollBarImageColor3", "Muted")
			local layout = Utility.ListLayout(listFrame, { Padding = 2 })
			Utility.ConnectCanvas(listFrame, layout)

			buildItems("")

			-- position popup under the button, clamped inside the window
			local rootAbs = scope.Window.Root.AbsolutePosition
			local rootSize = scope.Window.Root.AbsoluteSize
			local btnAbs = btn.AbsolutePosition
			local relX = btnAbs.X - rootAbs.X
			local relY = btnAbs.Y - rootAbs.Y + btn.AbsoluteSize.Y + 4
			local popupH = math.min(#values * 26 + (searchable and 34 or 0) + 16, 235)
			if relY + popupH > rootSize.Y - 10 then
				relY = math.max(btnAbs.Y - rootAbs.Y - popupH - 4, 4)
			end
			popup.Position = UDim2.new(0, relX, 0, relY)

			popup.GroupTransparency = 1
			Tween:Play(popup, "PanelSlide", { GroupTransparency = 0 })

			scope.Window:OpenPopupHandle(popup, function()
				closePopup()
			end)
		end

		closePopup = function()
			if not isOpen then
				return
			end
			isOpen = false
			Tween:Play(chevron, "Fast", { Rotation = 0 })
			if popup and popup.Parent then
				local p = popup
				Tween:Play(p, "Fast", { GroupTransparency = 1 })
				task.delay(0.15, function()
					if p.Parent then
						p:Destroy()
					end
				end)
			end
			popup = nil
		end

		btn.MouseButton1Click:Connect(function()
			if isOpen then
				closePopup()
			else
				openPopup()
			end
			Utility.Ripple(btn)
		end)

		refreshButton()

		------------------------------------------------------------------
		-- Public handle
		------------------------------------------------------------------
		local self = {
			Type = "Dropdown",
			Root = root,
			Flag = opts.Flag,
			Options = opts,
		}

		function self:Set(v, silent)
			if multi then
				selected = {}
				if type(v) == "table" then
					for _, item in ipairs(v) do
						selected[item] = true
					end
				end
			else
				selected = v
			end
			refreshButton()
			notifyFlag()
			if not silent then
				fire()
			end
		end

		function self:ConfigSet(v)
			-- stored value is a string or an array of strings
			if multi and type(v) == "table" then
				selected = {}
				for _, item in ipairs(v) do
					selected[item] = true
				end
			elseif not multi then
				selected = v
			end
			refreshButton()
		end

		function self:Get()
			if multi then
				local arr = {}
				for _, v in ipairs(values) do
					if selected[v] then
						table.insert(arr, v)
					end
				end
				return arr
			end
			return selected
		end

		function self:Refresh(newValues, keepSelection)
			values = newValues or values
			if not keepSelection then
				if multi then
					selected = {}
				else
					selected = values[1]
				end
			end
			refreshButton()
			if isOpen then
				buildItems(searchBox and searchBox.Text or "")
			end
		end

		function self:OnChanged(fn)
			table.insert(listeners, fn)
		end

		function self:Destroy()
			closePopup()
			root:Destroy()
			if self.Flag then
				Shared.Config:Unregister(self.Flag)
			end
		end

		if opts.Tooltip then
			Shared.Tooltip:Attach(root, opts.Tooltip)
		end
		if self.Flag then
			Shared.Config:Register(self)
		end

		return self
	end

	return Dropdown
end

end)()

--===========================[ Components.ColorPicker ]===========================--
__MODULES["Components.ColorPicker"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Components/ColorPicker.lua
-- HSV color editor that expands inline below its card: hue slider, optional
-- alpha slider, RGB sliders, hex input, preview swatch, rainbow mode.
--
--   Section:ColorPicker({ Title="ESP Color", Default=Color3.fromRGB(90,160,255),
--       Flag="ESPColor", Callback=function(color, alpha) end })
--   handle:Set(Color3.new(1,0,0))
--[[==========================================================================]]

return function(Shared)
	local ColorPicker = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons
	local UIS = Shared.Services.UserInputService

	------------------------------------------------------------------
	-- shared editor row factory (hue / R / G / B / alpha strip)
	------------------------------------------------------------------
	local function colorStrip(parent, labelText, gradientColors, initialAlpha)
		local wrap = Utility.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 14),
			Parent = parent,
		})
		local lab = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = Theme:Get("Muted"),
			Text = labelText,
			Size = UDim2.new(0, 18, 1, 0),
			Parent = wrap,
		})
		Utility.Paint(lab, "TextColor3", "Muted")

		local track = Utility.New("Frame", {
			BackgroundColor3 = Theme:Get("Element"),
			Position = UDim2.new(0, 22, 0.5, -5),
			Size = UDim2.new(1, -22, 0, 10),
			BorderSizePixel = 0,
			Parent = wrap,
		})
		Utility.Round(track, 5)
		if gradientColors then
			local seq = {}
			for i, c in ipairs(gradientColors) do
				seq[i] = ColorSequenceKeypoint.new((i - 1) / (#gradientColors - 1), c)
			end
			Utility.New("UIGradient", { Color = ColorSequence.new(seq), Parent = track })
		end

		local knob = Utility.New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Position = UDim2.new(initialAlpha or 0, 0, 0.5, 0),
			Size = UDim2.fromOffset(10, 10),
			ZIndex = 3,
			Parent = track,
		})
		Utility.Round(knob, 5)
		Utility.Stroke(knob, Color3.new(0, 0, 0), 1, 0.6)

		return track, knob
	end

	local function bindStrip(track, knob, getter, setter)
		local dragging = false
		track.InputBegan:Connect(function(input)
			if Utility.IsClick(input) then
				dragging = true
				local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
				setter(rel)
			end
		end)
		Utility.New("Frame", { Visible = false, Parent = track }) -- keep layout alive
		UIS.InputChanged:Connect(function(input)
			if dragging and Utility.IsMove(input) then
				local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
				setter(rel)
			end
		end)
		UIS.InputEnded:Connect(function(input)
			if Utility.IsClick(input) then
				dragging = false
			end
		end)
		return knob
	end

	------------------------------------------------------------------
	-- Main component
	------------------------------------------------------------------

	function ColorPicker.New(scope, opts)
		opts = opts or {}
		local h, s, v = Color3.toHSV(opts.Default or Color3.fromRGB(88, 148, 255))
		local alpha = opts.Alpha or opts.Transparency or 0
		local hasAlpha = opts.Alpha ~= nil or opts.ShowAlpha == true

		local root = Utility.New("Frame", {
			Name = "ColorPicker_" .. (opts.Title or "?"),
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			ClipsDescendants = true,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Card")
		Utility.Round(root, 8)
		Utility.Stroke(root, "Stroke", 1, 0.6)
		Utility.Pad(root, 10, 8, 10, 10)

		local col = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.ListLayout(col, { Padding = 6 })

		-- header: title + swatch + expand chevron
		local header = Utility.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			Parent = col,
		})
		Utility.ListLayout(header, { Direction = "Horizontal", Padding = 8, Vertical = "Center" })

		local title = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -80, 1, 0),
			Text = opts.Title or "Color",
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = header,
		})
		Utility.Paint(title, "TextColor3", "Text")

		local swatch = Utility.New("TextButton", {
			Name = "Swatch",
			BackgroundColor3 = Color3.fromHSV(h, s, v),
			Size = UDim2.fromOffset(36, 20),
			Text = "",
			AutoButtonColor = false,
			Parent = header,
		})
		Utility.Round(swatch, 5)
		Utility.Stroke(swatch, Color3.new(1, 1, 1), 1, 0.65)

		local chevron = Icons:Create("chevron-down", {
			Size = 12, Color = "Muted",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = header, Name = "Chevron",
		})

		-- expandable editor ------------------------------------------------
		local editor = Utility.New("Frame", {
			Name = "Editor",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Visible = false,
			Parent = col,
		})
		Utility.ListLayout(editor, { Padding = 6 })

		local preview = Utility.New("Frame", {
			BackgroundColor3 = Color3.fromHSV(h, s, v),
			Size = UDim2.new(1, 0, 0, 22),
			Parent = editor,
		})
		Utility.Round(preview, 6)
		local previewLabel = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.6,
			Text = "#FFFFFF",
			Size = UDim2.fromScale(1, 1),
			Parent = preview,
		})

		-- saturation/value picker square
		local svFrame = Utility.New("Frame", {
			Name = "SV",
			BackgroundColor3 = Color3.fromHSV(h, 1, 1),
			Size = UDim2.new(1, 0, 0, 90),
			Parent = editor,
		})
		Utility.Round(svFrame, 8)
		Utility.Stroke(svFrame, "Stroke", 1, 0.5)
		local svWhite = Utility.New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Parent = svFrame })
		Utility.Round(svWhite, 8)
		Utility.New("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
			Parent = svWhite,
		})
		local svBlack = Utility.New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = svWhite })
		Utility.New("UIGradient", {
			Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0)),
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
			Parent = svBlack,
		})
		local svKnob = Utility.New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Position = UDim2.new(s, 0, 1 - v, 0),
			Size = UDim2.fromOffset(12, 12),
			ZIndex = 4,
			Parent = svWhite,
		})
		Utility.Round(svKnob, 6)
		Utility.Stroke(svKnob, Color3.new(0, 0, 0), 2, 0.3)

		-- hue strip
		local hueTrack, hueKnob = colorStrip(editor, "H", {
			Color3.fromHSV(0, 1, 1), Color3.fromHSV(0.17, 1, 1), Color3.fromHSV(0.33, 1, 1),
			Color3.fromHSV(0.5, 1, 1), Color3.fromHSV(0.67, 1, 1), Color3.fromHSV(0.83, 1, 1),
			Color3.fromHSV(1, 1, 1),
		}, h)

		-- alpha strip (optional)
		local alphaTrack, alphaKnob
		if hasAlpha then
			alphaTrack, alphaKnob = colorStrip(editor, "A", {
				Color3.fromHSV(h, s, v), Color3.fromHSV(h, s, v),
			}, 1 - alpha)
			-- proper checkerboard-ish background behind the alpha gradient
			alphaTrack.BackgroundColor3 = Theme:Get("Element")
		end

		-- hex input
		local hexWrap = Utility.New("Frame", {
			BackgroundColor3 = Theme:Get("Input"),
			Size = UDim2.new(1, 0, 0, 24),
			Parent = editor,
		})
		Utility.Paint(hexWrap, "BackgroundColor3", "Input")
		Utility.Round(hexWrap, 6)
		local hexBox = Utility.New("TextBox", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 11,
			TextColor3 = Theme:Get("Text"),
			Text = "",
			PlaceholderText = "#RRGGBB",
			PlaceholderColor3 = Theme:Get("Muted"),
			Position = UDim2.new(0, 8, 0, 0),
			Size = UDim2.new(1, -60, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = hexWrap,
		})
		Utility.Paint(hexBox, "TextColor3", "Text")

		local copyBtn = Utility.New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.fromOffset(20, 16),
			Text = "",
			BackgroundColor3 = Theme:Get("Element"),
			AutoButtonColor = false,
			Parent = hexWrap,
		})
		Utility.Paint(copyBtn, "BackgroundColor3", "Element")
		Utility.Round(copyBtn, 4)
		local copyIcon = Icons:Create("copy", { Size = 10, Color = "Muted", Parent = copyBtn,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })

		-- rainbow toggle chip
		local rainbowBtn = Utility.New("TextButton", {
			BackgroundColor3 = Theme:Get("Element"),
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Theme:Get("Muted"),
			Text = "  Rainbow: Off",
			Size = UDim2.new(1, 0, 0, 22),
			AutoButtonColor = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = editor,
		})
		Utility.Paint(rainbowBtn, "BackgroundColor3", "Element")
		Utility.Round(rainbowBtn, 6)

		------------------------------------------------------------------
		-- state & mutation
		------------------------------------------------------------------
		local listeners = {}
		local rainbow = false
		local expanded = false

		local self = {
			Type = "ColorPicker",
			Root = root,
			Flag = opts.Flag,
			Options = opts,
		}

		local function currentColor()
			return Color3.fromHSV(h, s, v)
		end

		local function paint()
			local c = currentColor()
			swatch.BackgroundColor3 = c
			preview.BackgroundColor3 = c
			svFrame.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
			svKnob.Position = UDim2.new(s, 0, 1 - v, 0)
			local hex = string.format("#%02X%02X%02X",
				math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
			if hexBox.Text ~= hex then
				hexBox.Text = hex
				previewLabel.Text = hex
			end
			if hasAlpha and alphaKnob then
				alphaKnob.Position = UDim2.new(1 - alpha, 0, 0.5, 0)
			end
		end

		local function commit(silent)
			paint()
			if self.Flag then
				Shared.Config:NotifyChange(self.Flag, { Color = currentColor(), Alpha = alpha })
			end
			if not silent then
				if opts.Callback then
					task.spawn(function()
						pcall(opts.Callback, currentColor(), alpha)
					end)
				end
				for _, fn in ipairs(listeners) do
					task.spawn(fn, currentColor(), alpha)
				end
			end
		end

		-- interactions
		local svDragging = false
		svWhite.InputBegan:Connect(function(input)
			if Utility.IsClick(input) then
				svDragging = true
				local rx = math.clamp((input.Position.X - svWhite.AbsolutePosition.X) / svWhite.AbsoluteSize.X, 0, 1)
				local ry = math.clamp((input.Position.Y - svWhite.AbsolutePosition.Y) / svWhite.AbsoluteSize.Y, 0, 1)
				s = rx
				v = 1 - ry
				commit()
			end
		end)
		UIS.InputChanged:Connect(function(input)
			if svDragging and Utility.IsMove(input) then
				local rx = math.clamp((input.Position.X - svWhite.AbsolutePosition.X) / svWhite.AbsoluteSize.X, 0, 1)
				local ry = math.clamp((input.Position.Y - svWhite.AbsolutePosition.Y) / svWhite.AbsoluteSize.Y, 0, 1)
				s = rx
				v = 1 - ry
				commit()
			end
		end)
		UIS.InputEnded:Connect(function(input)
			if Utility.IsClick(input) then
				svDragging = false
			end
		end)

		bindStrip(hueTrack, hueKnob, nil, function(rel)
			h = rel
			commit()
		end)
		if hasAlpha and alphaTrack then
			bindStrip(alphaTrack, alphaKnob, nil, function(rel)
				alpha = 1 - rel
				commit()
			end)
		end

		hexBox.FocusLost:Connect(function(enter)
			if not enter then
				return
			end
			local ok, c = pcall(Utility.HexToColor3, hexBox.Text)
			if ok and c then
				h, s, v = Color3.toHSV(c)
				commit()
			else
				paint()
			end
		end)

		copyBtn.MouseButton1Click:Connect(function()
			local c = currentColor()
			local hex = string.format("#%02X%02X%02X",
				math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
			if setclipboard then
				pcall(setclipboard, hex)
			end
			copyIcon.ImageColor3 = Theme:Get("Success")
			task.delay(0.6, function()
				if copyIcon.Parent then
					copyIcon.ImageColor3 = Theme:Get("Muted")
				end
			end)
		end)

		rainbowBtn.MouseButton1Click:Connect(function()
			rainbow = not rainbow
			rainbowBtn.Text = "  Rainbow: " .. (rainbow and "On" or "Off")
			Utility.Paint(rainbowBtn, "TextColor3", rainbow and "Accent" or "Muted")
		end)

		-- rainbow loop
		task.spawn(function()
			while root.Parent do
				if rainbow then
					h = (h + Shared.Services.RunService.RenderStepped:Wait() * 0.09) % 1
					commit(true) -- visual-only; avoid spamming user callback
					swatch.BackgroundColor3 = currentColor()
				else
					task.wait(0.2)
				end
			end
		end)

		-- expand/collapse
		local function setExpanded(x)
			expanded = x
			editor.Visible = x
			Tween:Play(chevron, "Fast", { Rotation = x and 180 or 0 })
		end
		swatch.MouseButton1Click:Connect(function()
			setExpanded(not expanded)
		end)
		header.InputBegan:Connect(function(input)
			if Utility.IsClick(input) then
				setExpanded(not expanded)
			end
		end)

		paint()

		------------------------------------------------------------------
		-- API
		------------------------------------------------------------------
		function self:Set(c, a)
			h, s, v = Color3.toHSV(c)
			if a then
				alpha = a
			end
			commit(false)
		end
		function self:SetQuiet(c, a)
			h, s, v = Color3.toHSV(c)
			if a then
				alpha = a
			end
			paint()
		end
		function self:ConfigSet(data)
			if type(data) == "table" and data.Color then
				self:SetQuiet(data.Color, data.Alpha)
			elseif typeof(data) == "Color3" then
				self:SetQuiet(data)
			end
		end
		function self:Get()
			return currentColor(), alpha
		end
		function self:OnChanged(fn)
			table.insert(listeners, fn)
		end
		function self:Destroy()
			root:Destroy()
			if self.Flag then
				Shared.Config:Unregister(self.Flag)
			end
		end

		if opts.Tooltip then
			Shared.Tooltip:Attach(root, opts.Tooltip)
		end
		if self.Flag then
			Shared.Config:Register(self)
		end

		return self
	end

	----------------------------------------------------------------------
	-- Embedded swatch chip for Toggle:AddColorPicker
	----------------------------------------------------------------------
	function ColorPicker.NewEmbedding(scope, opts, parent)
		opts = opts or {}
		local small = Utility.New("TextButton", {
			Name = "ColorChip",
			BackgroundColor3 = opts.Default or Color3.fromRGB(88, 148, 255),
			Size = UDim2.fromOffset(20, 14),
			Text = "",
			AutoButtonColor = false,
			Parent = parent,
		})
		Utility.Round(small, 4)
		Utility.Stroke(small, Color3.new(1, 1, 1), 1, 0.7)

		-- clicking opens a full picker appended to the section page
		local opened
		small.MouseButton1Click:Connect(function()
			if opened and opened.Root and opened.Root.Parent then
				opened:Destroy()
				opened = nil
				return
			end
			local newScope = {
				Window = scope.Window,
				Page = parent.Parent and parent.Parent.Parent and parent.Parent.Parent.Parent or scope.Page,
				Index = (scope.Index or 0) + 1,
				Section = scope.Section,
			}
			opened = ColorPicker.New(newScope, {
				Title = opts.Title or "Color",
				Default = small.BackgroundColor3,
				Callback = function(c)
					small.BackgroundColor3 = c
					if opts.Callback then
						opts.Callback(c)
					end
				end,
			})
		end)

		local handle = {
			Type = "ColorChip",
			Root = small,
			Flag = opts.Flag,
		}
		function handle:Set(c)
			small.BackgroundColor3 = c
			if opened and opened.SetQuiet then
				opened:SetQuiet(c)
			end
		end
		function handle:ConfigSet(data)
			local c = type(data) == "table" and data.Color or data
			if typeof(c) == "Color3" then
				small.BackgroundColor3 = c
			end
		end
		function handle:Get()
			return small.BackgroundColor3
		end
		function handle:Destroy()
			if opened then
				opened:Destroy()
			end
			small:Destroy()
		end
		return handle
	end

	return ColorPicker
end

end)()

--===========================[ Components.Keybind ]===========================--
__MODULES["Components.Keybind"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Components/Keybind.lua
-- Key picker with modes (Toggle / Hold / Always). Click chip to rebind,
-- Esc cancels, Backspace/Delete unbinds. Hold mode fires on press/release.
--
--   local kb = Section:Keybind({ Title="Fly", Default="F", Flag="FlyKey",
--       Mode="Toggle", Callback=function(active) end })
--   kb:SetKey(Enum.KeyCode.Q)
--
-- Also provides Keybind.NewEmbedding(scope, opts, parent) â€” compact chip
-- used by Toggle:AddKeybind().
--[[==========================================================================]]

return function(Shared)
	local Keybind = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local UIS = Shared.Services.UserInputService

	Shared.Keybinds = Shared.Keybinds or {} -- registry for the KeybindList addon

	----------------------------------------------------------------------
	-- Core logic factory (shared by card + embedded forms)
	----------------------------------------------------------------------

	local function MakeBinder(handle, opts)
		handle.Value = opts.Default or nil
		handle.Mode = opts.Mode or "Toggle" -- Toggle | Hold | Always
		handle.State = false -- current activation state

		local listening = false

		function handle:IsListening()
			return listening
		end

		function handle:SetListening(v)
			listening = v
		end

		function handle:SetKey(key, silent)
			if type(key) == "string" then
				key = Utility.KeyFromName(key)
			end
			handle.Value = key
			if handle._paint then
				handle._paint()
			end
			if handle.Flag then
				local encoded = key and key.Name or "None"
				Shared.Config:NotifyChange(handle.Flag, encoded)
			end
			if not silent and opts.Callback and handle.Mode == "Always" and key == nil then
				-- unbinding an Always bind = deactivate
				handle.State = false
			end
		end

		function handle:GetKey()
			return handle.Value
		end

		function handle:GetState()
			return handle.State
		end

		function handle:SetMode(m)
			if m == "Toggle" or m == "Hold" or m == "Always" then
				handle.Mode = m
				if handle._paint then
					handle._paint()
				end
			end
		end

		local function activate(active)
			handle.State = active
			if opts.Callback then
				task.spawn(function()
					pcall(opts.Callback, active)
				end)
			end
			if handle._onState then
				handle._onState(active)
			end
		end

		function handle:_press()
			if handle.Mode == "Toggle" then
				activate(not handle.State)
			elseif handle.Mode == "Hold" then
				activate(true)
			else
				activate(true)
			end
			if opts.OnPress then
				pcall(opts.OnPress)
			end
		end

		function handle:_release()
			if handle.Mode == "Hold" then
				activate(false)
			end
			if opts.OnRelease then
				pcall(opts.OnRelease)
			end
		end

		-- global input listening
		local conns = {}
		table.insert(conns, UIS.InputBegan:Connect(function(input, gpe)
			if listening then
				if input.UserInputType == Enum.UserInputType.Keyboard then
					local kc = input.KeyCode
					if kc == Enum.KeyCode.Escape then
						listening = false
						if handle._paint then
							handle._paint()
						end
						return
					end
					if kc == Enum.KeyCode.Backspace or kc == Enum.KeyCode.Delete then
						listening = false
						handle:SetKey(nil)
						return
					end
					listening = false
					handle:SetKey(kc)
				end
				return
			end
			if gpe or Utility.IsTyping() then
				return
			end
			if handle.Value and input.KeyCode == handle.Value then
				handle:_press()
			end
		end))
		table.insert(conns, UIS.InputEnded:Connect(function(input)
			if handle.Value and input.KeyCode == handle.Value then
				handle:_release()
			end
		end))

		function handle:_destroyConns()
			for _, c in ipairs(conns) do
				c:Disconnect()
			end
		end

		-- register for KeybindList addon
		local entry = { Title = opts.Title or "Keybind", Ref = handle }
		table.insert(Shared.Keybinds, entry)
		handle._entry = entry

		function handle:_unregister()
			for i, e in ipairs(Shared.Keybinds) do
				if e == entry then
					table.remove(Shared.Keybinds, i)
					break
				end
			end
		end

		function handle:ConfigSet(encoded)
			if encoded == "None" or encoded == nil then
				handle:SetKey(nil, true)
			elseif type(encoded) == "string" then
				handle:SetKey(Utility.KeyFromName(encoded), true)
			elseif typeof(encoded) == "EnumItem" then
				handle:SetKey(encoded, true)
			end
		end

		return handle
	end

	----------------------------------------------------------------------
	-- Full-row keybind card
	----------------------------------------------------------------------

	function Keybind.New(scope, opts)
		opts = opts or {}
		local root = Utility.New("Frame", {
			Name = "Keybind_" .. (opts.Title or "?"),
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Card")
		Utility.Round(root, 8)
		Utility.Stroke(root, "Stroke", 1, 0.6)
		Utility.Pad(root, 10, 8, 10, 8)

		local row = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.ListLayout(row, { Direction = "Horizontal", Padding = 6, Vertical = "Center" })

		local title = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -90, 0, 0),
			Text = opts.Title or "Keybind",
			Parent = row,
		})
		Utility.Paint(title, "TextColor3", "Text")

		-- mode cycle button
		local modeBtn = Utility.New("TextButton", {
			Name = "Mode",
			BackgroundColor3 = Theme:Get("Element"),
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextColor3 = Theme:Get("Muted"),
			Text = " Toggle ",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 18),
			AutoButtonColor = false,
			Parent = row,
		})
		Utility.Paint(modeBtn, "BackgroundColor3", "Element")
		Utility.Paint(modeBtn, "TextColor3", "Muted")
		Utility.Round(modeBtn, 4)

		-- key chip
		local chip = Utility.New("TextButton", {
			Name = "Key",
			BackgroundColor3 = Theme:Get("Input"),
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Theme:Get("Text"),
			Text = " None ",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 36, 0, 20),
			AutoButtonColor = false,
			Parent = row,
		})
		Utility.Paint(chip, "BackgroundColor3", "Input")
		Utility.Paint(chip, "TextColor3", "Text")
		Utility.Round(chip, 5)
		Utility.Stroke(chip, "Stroke", 1, 0.5)

		local handle = {
			Type = "Keybind",
			Root = root,
			Flag = opts.Flag,
			Options = opts,
		}
		MakeBinder(handle, opts)

		function handle._paint()
			chip.Text = " " .. Utility.KeyName(handle.Value) .. " "
			modeBtn.Text = " " .. handle.Mode .. " "
			if handle:IsListening() then
				chip.Text = " ... "
				Tween:Play(chip, "Fast", { BackgroundColor3 = Theme:Get("Accent") })
			else
				Tween:Play(chip, "Fast", { BackgroundColor3 = Theme:Get("Input") })
			end
		end

		chip.MouseButton1Click:Connect(function()
			if handle:IsListening() then
				handle:SetListening(false)
			else
				handle:SetListening(true)
			end
			handle._paint()
		end)

		modeBtn.MouseButton1Click:Connect(function()
			Utility.Ripple(modeBtn)
			local order = { "Toggle", "Hold", "Always" }
			local idx = table.find(order, handle.Mode) or 1
			handle:SetMode(order[idx % 3 + 1])
			handle._paint()
		end)
		if opts.AllowModeCycle == false then
			modeBtn.Visible = false
			title.Size = UDim2.new(1, -60, 0, 0)
		end

		handle._paint()

		if opts.Tooltip then
			Shared.Tooltip:Attach(root, opts.Tooltip)
		end

		function handle:Set(key)
			handle:SetKey(key)
		end
		function handle:Get()
			return handle.Value and handle.Value.Name or "None"
		end
		function handle:Destroy()
			handle:_destroyConns()
			handle:_unregister()
			root:Destroy()
		end

		if opts.Flag then
			Shared.Config:Register(handle)
		end

		return handle
	end

	-- (see note in file footer: self_flag_guard is defined below)

	----------------------------------------------------------------------
	-- Embedded chip form (used by Toggle:AddKeybind)
	----------------------------------------------------------------------

	function Keybind.NewEmbedding(scope, opts, parent)
		opts = opts or {}
		local chip = Utility.New("TextButton", {
			Name = "KeyChip",
			BackgroundColor3 = Theme:Get("Input"),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = Theme:Get("Text"),
			Text = " None ",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 26, 0, 16),
			AutoButtonColor = false,
			Parent = parent,
		})
		Utility.Paint(chip, "BackgroundColor3", "Input")
		Utility.Paint(chip, "TextColor3", "Text")
		Utility.Round(chip, 4)
		Utility.Stroke(chip, "Stroke", 1, 0.5)

		local handle = {
			Type = "KeybindChip",
			Root = chip,
			Flag = opts.Flag,
			Options = opts,
		}
		MakeBinder(handle, opts)
		if opts.Mode then
			handle:SetMode(opts.Mode)
		end

		function handle._paint()
			chip.Text = " " .. Utility.KeyName(handle.Value) .. " "
		end
		handle._paint()

		chip.MouseButton1Click:Connect(function()
			handle:SetListening(not handle:IsListening())
			chip.Text = handle:IsListening() and " ... " or (" " .. Utility.KeyName(handle.Value) .. " ")
			Tween:Play(chip, "Fast", {
				BackgroundColor3 = handle:IsListening() and Theme:Get("Accent") or Theme:Get("Input"),
			})
		end)

		-- when the owning toggle flips, optionally activate bind state
		if opts._embeddedToggle and handle.Mode == "Toggle" then
			opts._embeddedToggle:OnChanged(function(v)
				-- keep chip state mirrored without double-calling user callback:
				handle.State = v and true or handle.State
			end)
		end

		function handle:Get()
			return handle.Value and handle.Value.Name or "None"
		end
		function handle:Destroy()
			handle:_destroyConns()
			handle:_unregister()
			chip:Destroy()
		end

		return handle
	end

    return Keybind
end

end)()

--===========================[ Components.Input ]===========================--
__MODULES["Components.Input"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Components/Input.lua
-- Text input row: placeholder, clear button, numeric filter, max length,
-- focus ring animation, FireOn = "Change" | "Enter" | "FocusLost".
--
--   Section:Input({ Title="Name", Placeholder="player name", Flag="Name",
--       Callback=function(text, enterPressed) end })
--[[==========================================================================]]

return function(Shared)
	local Input = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	function Input.New(scope, opts)
		opts = opts or {}
		local value = tostring(opts.Default or "")

		local root = Utility.New("Frame", {
			Name = "Input_" .. (opts.Title or "?"),
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Card")
		Utility.Round(root, 8)
		Utility.Stroke(root, "Stroke", 1, 0.6)
		Utility.Pad(root, 10, 8, 10, 8)

		local col = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.ListLayout(col, { Padding = 4 })

		local title = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 16),
			Text = opts.Title or "Input",
			Parent = col,
		})
		Utility.Paint(title, "TextColor3", "Text")

		local fieldWrap = Utility.New("Frame", {
			Name = "Field",
			BackgroundColor3 = Theme:Get("Input"),
			Size = UDim2.new(1, 0, 0, 28),
			Parent = col,
		})
		Utility.Paint(fieldWrap, "BackgroundColor3", "Input")
		Utility.Round(fieldWrap, 7)
		local fieldStroke = Utility.Stroke(fieldWrap, "Stroke", 1, 0.4)

		local box = Utility.New("TextBox", {
			Name = "TextBox",
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			PlaceholderText = opts.Placeholder or "Type...",
			PlaceholderColor3 = Theme:Get("Muted"),
			Text = value,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = opts.ClearTextOnFocus == true,
			Size = UDim2.new(1, -36, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			Parent = fieldWrap,
		})
		Utility.Paint(box, "TextColor3", "Text")
		Utility.Paint(box, "PlaceholderColor3", "Muted")

		-- clear button
		local clear = Utility.New("TextButton", {
			Name = "Clear",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -5, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 1,
			Text = "",
			Visible = value ~= "",
			AutoButtonColor = false,
			Parent = fieldWrap,
		})
		local clearIcon = Icons:Create("x", {
			Size = 12, Color = "Muted", Parent = clear,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		})
		clear.MouseButton1Click:Connect(function()
			box.Text = ""
			box:CaptureFocus()
		end)

		local self = {
			Type = "Input",
			Root = root,
			Flag = opts.Flag,
			Options = opts,
			Value = value,
		}

		local function filter(text)
			if opts.MaxCharacters and #text > opts.MaxCharacters then
				text = text:sub(1, opts.MaxCharacters)
			end
			if opts.Numeric then
				text = text:gsub("[^%d%.%-]", "")
			end
			return text
		end

		local listeners = {}
		local fireOn = opts.FireOn or (opts.EnterPressedOnly and "Enter") or "Change"

		local function fire(enterPressed)
			self.Value = box.Text
			if self.Flag then
				Shared.Config:NotifyChange(self.Flag, self.Value)
			end
			if opts.Callback then
				task.spawn(function()
					pcall(opts.Callback, self.Value, enterPressed)
				end)
			end
			for _, fn in ipairs(listeners) do
				task.spawn(fn, self.Value)
			end
		end

		box:GetPropertyChangedSignal("Text"):Connect(function()
			local filtered = filter(box.Text)
			if filtered ~= box.Text then
				box.Text = filtered
				return
			end
			clear.Visible = box.Text ~= ""
			if fireOn == "Change" then
				fire(false)
			end
		end)

		box.Focused:Connect(function()
			Tween:Play(fieldStroke, "Fast", { Color = Theme:Get("Accent"), Transparency = 0.1 })
		end)

		box.FocusLost:Connect(function(enter)
			Tween:Play(fieldStroke, "Fast", { Color = Theme:Get("Stroke"), Transparency = 0.4 })
			if fireOn == "FocusLost" or (fireOn == "Enter" and enter) then
				fire(enter)
			end
			if fireOn == "Change" and enter and opts.FinishOnEnter == true then
				fire(true)
			end
		end)

		function self:Set(text)
			box.Text = tostring(text or "")
		end
		function self:Get()
			return box.Text
		end
		function self:ConfigSet(v)
			box.Text = tostring(v or "")
			self.Value = box.Text
		end
		function self:SetPlaceholder(t)
			box.PlaceholderText = tostring(t)
		end
		function self:OnChanged(fn)
			table.insert(listeners, fn)
		end
		function self:Destroy()
			root:Destroy()
			if self.Flag then
				Shared.Config:Unregister(self.Flag)
			end
		end

		if opts.Tooltip then
			Shared.Tooltip:Attach(root, opts.Tooltip)
		end
		if self.Flag then
			Shared.Config:Register(self)
		end

		return self
	end

	return Input
end

end)()

--===========================[ Components.Label ]===========================--
__MODULES["Components.Label"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Components/Label.lua
-- Simple text row with optional icon and color. :Set(text).
--[[==========================================================================]]

return function(Shared)
	local Label = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Icons = Shared.Icons

	function Label.New(scope, opts)
		opts = opts or {}
		local root = Utility.New("Frame", {
			Name = "Label",
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", opts.Flat and "Card" or "Card")
		Utility.Round(root, 8)
		Utility.Stroke(root, "Stroke", 1, 0.75)
		Utility.Pad(root, 10, 7, 10, 7)

		local row = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.ListLayout(row, { Direction = "Horizontal", Padding = 8, Vertical = "Center" })

		if opts.Icon then
			Icons:Create(opts.Icon, { Size = 14, Color = opts.IconColor or "Accent", Parent = row })
		end

		local text = Utility.New("TextLabel", {
			Name = "Text",
			BackgroundTransparency = 1,
			Font = opts.Bold and Enum.Font.GothamBold or Enum.Font.Gotham,
			TextSize = opts.TextSize or 12,
			TextColor3 = Theme:Get(opts.Color or "SubText"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			RichText = opts.RichText == true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, opts.Icon and -24 or 0, 0, 0),
			Text = tostring(opts.Title or opts.Text or ""),
			Parent = row,
		})
		Utility.Paint(text, "TextColor3", opts.Color or "SubText")

		local self = {
			Type = "Label",
			Root = root,
			Value = tostring(opts.Title or opts.Text or ""),
			Options = opts,
		}

		function self:Set(v)
			self.Value = tostring(v)
			text.Text = tostring(v)
		end

		function self:SetColor(color)
			if type(color) == "string" then
				Utility.Paint(text, "TextColor3", color)
			elseif typeof(color) == "Color3" then
				text.TextColor3 = color
			end
		end

		function self:Get()
			return text.Text
		end

		function self:Destroy()
			root:Destroy()
		end

		return self
	end

	return Label
end

end)()

--===========================[ Components.Paragraph ]===========================--
__MODULES["Components.Paragraph"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Components/Paragraph.lua
-- Title + multi-line body card, optional icon. :SetTitle / :SetContent / :Set(table)
--[[==========================================================================]]

return function(Shared)
	local Paragraph = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Icons = Shared.Icons

	function Paragraph.New(scope, opts)
		opts = opts or {}
		local root = Utility.New("Frame", {
			Name = "Paragraph",
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Card")
		Utility.Round(root, 8)
		Utility.Stroke(root, "Stroke", 1, 0.6)
		Utility.Pad(root, 12, 10, 12, 10)

		local col = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.ListLayout(col, { Padding = 4 })

		-- header (optional icon + title)
		local header = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = col,
		})
		Utility.ListLayout(header, { Direction = "Horizontal", Padding = 8, Vertical = "Center" })

		if opts.Icon then
			Icons:Create(opts.Icon, { Size = 16, Color = opts.IconColor or "Accent", Parent = header })
		end

		local title = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, opts.Icon and -26 or 0, 0, 0),
			Text = opts.Title or "Info",
			TextWrapped = true,
			Parent = header,
		})
		Utility.Paint(title, "TextColor3", "Text")

		local content = Utility.New("TextLabel", {
			Name = "Content",
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Theme:Get("SubText"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			RichText = opts.RichText == true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Text = opts.Content or "",
			Parent = col,
		})
		Utility.Paint(content, "TextColor3", "SubText")
		content.Visible = (opts.Content or "") ~= ""

		local self = {
			Type = "Paragraph",
			Root = root,
			Options = opts,
			Value = { Title = opts.Title, Content = opts.Content },
		}

		function self:SetTitle(t)
			title.Text = tostring(t)
		end

		function self:SetContent(c)
			content.Text = tostring(c or "")
			content.Visible = content.Text ~= ""
		end

		function self:Set(opts2)
			opts2 = opts2 or {}
			if opts2.Title then
				self:SetTitle(opts2.Title)
			end
			if opts2.Content ~= nil then
				self:SetContent(opts2.Content)
			end
		end

		function self:Get()
			return { Title = title.Text, Content = content.Text }
		end

		function self:Destroy()
			root:Destroy()
		end

		return self
	end

	return Paragraph
end

end)()

--===========================[ Components.Divider ]===========================--
__MODULES["Components.Divider"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Components/Divider.lua
-- Horizontal separator, optionally with centered label text.
--[[==========================================================================]]

return function(Shared)
	local Divider = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme

	function Divider.New(scope, opts)
		opts = opts or {}
		local root = Utility.New("Frame", {
			Name = "Divider",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 12),
			LayoutOrder = scope.Index,
			Parent = scope.Page,
		})

		local hasText = opts.Text ~= nil and opts.Text ~= ""

		local lineL = Utility.New("Frame", {
			Name = "LineL",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(hasText and 0.35 or 1, hasText and -10 or 0, 0, 1),
			BackgroundColor3 = Theme:Get("Divider"),
			BorderSizePixel = 0,
			Parent = root,
		})
		Utility.Paint(lineL, "BackgroundColor3", "Divider")
		Utility.Round(lineL, 1)

		local lab
		if hasText then
			lab = Utility.New("TextLabel", {
				Name = "Text",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 0, 12),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
				TextColor3 = Theme:Get("Muted"),
				Text = string.upper(tostring(opts.Text)),
				Parent = root,
			})
			Utility.Paint(lab, "TextColor3", "Muted")

			local lineR = Utility.New("Frame", {
				Name = "LineR",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0.35, -10, 0, 1),
				BackgroundColor3 = Theme:Get("Divider"),
				BorderSizePixel = 0,
				Parent = root,
			})
			Utility.Paint(lineR, "BackgroundColor3", "Divider")
			Utility.Round(lineR, 1)

			-- keep side lines balanced when text width changes
			lab:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				local w = lab.AbsoluteSize.X
				local avail = root.AbsoluteSize.X
				if avail <= 0 or w <= 0 then
					return
				end
				local side = math.max((avail - w - 16) / 2 / avail, 0.05)
				lineL.Size = UDim2.new(side, 0, 0, 1)
				lineR.Size = UDim2.new(side, 0, 0, 1)
			end)
		end

		local self = { Type = "Divider", Root = root, Options = opts }
		function self:SetText(t)
			if lab then
				lab.Text = string.upper(tostring(t))
			end
		end
		function self:Destroy()
			root:Destroy()
		end
		return self
	end

	return Divider
end

end)()

--===========================[ Components.ProgressBar ]===========================--
__MODULES["Components.ProgressBar"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Components/ProgressBar.lua
-- Title + gradient progress track with percentage/read-out label.
--
--   local p = Section:ProgressBar({ Title="Loading", Value=30, Max=100 })
--   p:Set(65); p:SetText("65 / 100 items")
--[[==========================================================================]]

return function(Shared)
	local ProgressBar = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween

	function ProgressBar.New(scope, opts)
		opts = opts or {}
		local max = tonumber(opts.Max) or 100
		local value = math.clamp(tonumber(opts.Value or opts.Default) or 0, 0, max)

		local root = Utility.New("Frame", {
			Name = "Progress",
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Card")
		Utility.Round(root, 8)
		Utility.Stroke(root, "Stroke", 1, 0.6)
		Utility.Pad(root, 10, 8, 10, 10)

		local col = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.ListLayout(col, { Padding = 6 })

		local header = Utility.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			Parent = col,
		})

		local title = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(0.6, 0, 1, 0),
			Text = opts.Title or "Progress",
			Parent = header,
		})
		Utility.Paint(title, "TextColor3", "Text")

		local valueLabel = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Theme:Get("Accent"),
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.6, 0, 0, 0),
			Size = UDim2.new(0.4, 0, 1, 0),
			Text = tostring(math.floor(value)) .. "/" .. tostring(max),
			Parent = header,
		})
		Utility.Paint(valueLabel, "TextColor3", "Accent")

		local track = Utility.New("Frame", {
			Name = "Track",
			BackgroundColor3 = Theme:Get("Element"),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 8),
			Parent = col,
		})
		Utility.Paint(track, "BackgroundColor3", "Element")
		Utility.Round(track, 4)

		local fill = Utility.New("Frame", {
			Name = "Fill",
			BackgroundColor3 = Theme:Get("Accent"),
			BorderSizePixel = 0,
			Size = UDim2.new(value / max, 0, 1, 0),
			Parent = track,
		})
		Utility.Round(fill, 4)
		Utility.Gradient(fill, "Accent", "Accent2", 0)

		-- subtle shine sweep
		local shine = Utility.New("Frame", {
			Name = "Shine",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.85,
			Size = UDim2.new(0.25, 0, 1, 0),
			Parent = fill,
		})
		local shineGrad = Utility.New("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = shine,
		})
		local shineOn = false
		_ = shineGrad

		local self = {
			Type = "ProgressBar",
			Root = root,
			Options = opts,
			Value = value,
			Max = max,
		}

		function self:Set(v)
			value = math.clamp(tonumber(v) or 0, 0, max)
			self.Value = value
			Tween:Play(fill, "Snappy", { Size = UDim2.new(value / max, 0, 1, 0) })
			valueLabel.Text = tostring(math.floor(value + 0.5)) .. "/" .. tostring(max)
			if opts.Callback then
				task.spawn(function()
					pcall(opts.Callback, value, max)
				end)
			end
		end

		function self:SetMax(m)
			max = tonumber(m) or max
			self.Max = max
			self:Set(self.Value)
		end

		function self:SetText(t)
			valueLabel.Text = tostring(t)
		end

		function self:Get()
			return self.Value
		end

		function self:SetShine(on)
			shineOn = on and true or false
			if shineOn then
				task.spawn(function()
					while shineOn and shine.Parent do
						shine.Position = UDim2.new(-0.3, 0, 0, 0)
						local t = Tween:Play(shine, { Time = 1.4, Style = "Sine", Direction = "InOut" },
							{ Position = UDim2.new(1.05, 0, 0, 0) })
						if t then
							t.Completed:Wait()
						else
							break
						end
					end
				end)
			end
		end

		function self:Destroy()
			shineOn = false
			root:Destroy()
		end

		return self
	end

	return ProgressBar
end

end)()

--===========================[ Components.Image ]===========================--
__MODULES["Components.Image"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Components/Image.lua
-- Rounded image card (thumbnails, previews). Supports lucide icon fallback.
--
--   Section:Image({ Title="Map", Image="rbxassetid://123", Height=140 })
--[[==========================================================================]]

return function(Shared)
	local Image = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Icons = Shared.Icons

	function Image.New(scope, opts)
		opts = opts or {}
		local root = Utility.New("Frame", {
			Name = "Image",
			BackgroundColor3 = Theme:Get("Element"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			ClipsDescendants = true,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Element")
		Utility.Round(root, 10)
		Utility.Stroke(root, "Stroke", 1, 0.55)

		local holder = Utility.New("Frame", {
			Name = "Holder",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, opts.Height or 140),
			Parent = root,
		})

		local img = Utility.New("ImageLabel", {
			Name = "Img",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ScaleType = opts.ScaleType or Enum.ScaleType.Crop,
			Image = "",
			Parent = holder,
		})
		Utility.Round(img, 10)

		local function setImage(src)
			if type(src) ~= "string" or src == "" then
				img.Image = ""
				return
			end
			if src:match("^rbxasset") or src:match("://") then
				img.Image = src
			elseif Icons.Exists(src) then
				-- lucide icon fallback: centered icon instead of image fill
				img.Image = ""
				local ic = Icons:Create(src, {
					Size = 32, Color = "Muted",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Parent = holder,
					Name = "FallbackIcon",
				})
				ic.ZIndex = 2
			else
				img.Image = "rbxassetid://" .. src
			end
		end
		setImage(opts.Image or opts.Asset or opts.Icon)

		local title
		if opts.Title then
			title = Utility.New("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = Theme:Get("SubText"),
				TextXAlignment = Enum.TextXAlignment.Left,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				Text = opts.Title,
				Parent = root,
			})
			Utility.Paint(title, "TextColor3", "SubText")
			Utility.Pad(title, 4, 6, 0, 6)
			-- need container for padding to respect layout; simplest: put title below holder via list layout
			local layout = Utility.ListLayout(root, { Padding = 0 })
			holder.LayoutOrder = 1
			title.LayoutOrder = 2
			_ = layout
		end

		local self = {
			Type = "Image",
			Root = root,
			Options = opts,
			Value = opts.Image,
		}

		function self:Set(src)
			setImage(src)
			self.Value = src
		end
		function self:Get()
			return self.Value
		end
		function self:Destroy()
			root:Destroy()
		end

		return self
	end

	return Image
end

end)()

--===========================[ Components.Dialog ]===========================--
__MODULES["Components.Dialog"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Components/Dialog.lua
-- Modal confirmation dialog inside a window overlay.
--
--   Dialog.Open(window, {
--       Title = "Unload UI?", Content = "This cannot be undone.",
--       Buttons = { {Label="Cancel"}, {Label="Unload", Primary=true, Danger=true, Callback=fn} },
--       Dismissible = true,  Icon = "alert-triangle",
--   })
--[[==========================================================================]]

return function(Shared)
	local Dialog = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	function Dialog.Open(window, opts)
		opts = opts or {}
		local host = window.DialogHost or window.PopupLayer
		if not host then
			return nil
		end

		local dim = Utility.New("TextButton", {
			Name = "DialogDim",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 80,
			AutoButtonColor = false,
			Parent = host,
		})
		Tween:Play(dim, "Fade", { BackgroundTransparency = 0.5 })

		local box = Utility.New("Frame", {
			Name = "DialogBox",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 320, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme:Get("Surface"),
			ZIndex = 81,
			Parent = dim,
		})
		Utility.Paint(box, "BackgroundColor3", "Surface")
		Utility.Round(box, 14)
		Utility.Stroke(box, "StrokeHover", 1, 0.3)
		Utility.Pad(box, 16, 14, 16, 14)

		local scale = Utility.New("UIScale", { Scale = 0.9, Parent = box })
		Tween:Play(scale, "Dialog", { Scale = 1 })

		local col = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = box,
		})
		Utility.ListLayout(col, { Padding = 6 })

		if opts.Icon then
			Icons:Create(opts.Icon, { Size = 20, Color = opts.IconColor or "Accent", Parent = col })
		end

		local title = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = Theme:Get("Text"),
			Text = opts.Title or "Confirm",
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			ZIndex = 82,
			Parent = col,
		})
		Utility.Paint(title, "TextColor3", "Text")

		if opts.Content and opts.Content ~= "" then
			local content = Utility.New("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextColor3 = Theme:Get("SubText"),
				Text = opts.Content,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				ZIndex = 82,
				Parent = col,
			})
			Utility.Paint(content, "TextColor3", "SubText")
		end

		local btnRow = Utility.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = col,
		})
		Utility.ListLayout(btnRow, {
			Direction = "Horizontal",
			Padding = 8,
			Horizontal = "Right",
		})
		Utility.Pad(btnRow, 0, 8, 0, 0)

		local handle = { _dim = dim }
		local closed = false

		function handle:Close()
			if closed then
				return
			end
			closed = true
			Tween:Play(dim, "Fade", { BackgroundTransparency = 1 })
			if scale and scale.Parent then
				Tween:Play(scale, "Fast", { Scale = 0.92 })
			end
			task.delay(0.18, function()
				if dim.Parent then
					dim:Destroy()
				end
			end)
			if opts.OnClose then
				pcall(opts.OnClose)
			end
		end

		local buttons = opts.Buttons or { { Label = "OK", Primary = true } }
		for i, spec in ipairs(buttons) do
			spec = type(spec) == "string" and { Label = spec } or spec
			local primary = spec.Primary or (i == #buttons and #buttons == 1)
			local danger = spec.Danger == true
			local btn = Utility.New("TextButton", {
				BackgroundColor3 = primary and Theme:Get("Accent")
					or danger and Theme:Get("Danger") or Theme:Get("Element"),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = (primary or danger) and Theme:Get("AccentText") or Theme:Get("Text"),
				Text = spec.Label or spec.Title or "OK",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 64, 0, 30),
				AutoButtonColor = false,
				ZIndex = 83,
				Parent = btnRow,
			})
			Utility.Paint(btn, "BackgroundColor3",
				primary and "Accent" or danger and "Danger" or "Element")
			Utility.Paint(btn, "TextColor3", (primary or danger) and "AccentText" or "Text")
			Utility.Round(btn, 7)
			Utility.Pad(btn, 12, 0, 12, 0)
			Utility.HoverTint(btn, "BackgroundColor3",
				primary and "Accent" or danger and "Danger" or "Element",
				primary and "Accent" or danger and "Danger" or "ElementHover")
			btn.MouseButton1Click:Connect(function()
				if spec.Callback then
					pcall(spec.Callback)
				end
				handle:Close()
			end)
		end

		if opts.Dismissible ~= false then
			dim.MouseButton1Click:Connect(function(input)
				-- only dismiss via clicks outside the box
				local boxPos = box.AbsolutePosition
				local boxSize = box.AbsoluteSize
				local m = input.Position
				if m.X < boxPos.X or m.X > boxPos.X + boxSize.X
					or m.Y < boxPos.Y or m.Y > boxPos.Y + boxSize.Y then
					handle:Close()
				end
			end)
		end

		return handle
	end

	return Dialog
end

end)()

--===========================[ Containers.Section ]===========================--
__MODULES["Containers.Section"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Containers/Section.lua
-- Section (full-width block with header) and GroupBox (bordered card used in
-- tab side-by-side columns). Both share the element factory that builds UI
-- components through Shared.Components.
--
-- Every element created through a Section/GroupBox is:
--   * parented into the section body
--   * registered for window search (Search attribute set by Window)
--   * the returned handle is the component handle (:Set/:Get/:Destroy...)
--[[==========================================================================]]

return function(Shared)
	local Section = {}
	local GroupBox = {}

	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween

	----------------------------------------------------------------------
	-- Shared element factory â€” mixed into Section and GroupBox objects.
	----------------------------------------------------------------------

	local ElementFactory = {}

	local function MakeScope(self, searchText)
		return {
			Window = self._window,
			Page = self._body or self._page,
			Index = (self._index or 0) + 1,
			Section = self,
			Search = searchText,
		}
	end

	local function Track(self, element, searchText)
		self._index = (self._index or 0) + 1
		table.insert(self._elements, element)
		if self._window and self._window._registerElement then
			self._window:_registerElement(element, searchText, self)
		end
		return element
	end

	function ElementFactory:Button(opts, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Callback = callback }
		end
		opts = opts or {}
		local el = Shared.Components.Button.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	-- Support both Toggle(state, callback) and Toggle(table)
	function ElementFactory:Toggle(opts, default, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Default = default, Callback = callback }
		end
		opts = opts or {}
		local el = Shared.Components.Toggle.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	function ElementFactory:Slider(opts, min, max, default, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Min = min, Max = max, Default = default, Callback = callback }
		end
		opts = opts or {}
		local el = Shared.Components.Slider.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	function ElementFactory:Dropdown(opts, values, default, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Values = values, Default = default, Callback = callback }
		end
		opts = opts or {}
		local el = Shared.Components.Dropdown.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	function ElementFactory:ColorPicker(opts, default, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Default = default, Callback = callback }
		end
		opts = opts or {}
		local el = Shared.Components.ColorPicker.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	function ElementFactory:Keybind(opts, default, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Default = default, Callback = callback }
		end
		opts = opts or {}
		local el = Shared.Components.Keybind.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	function ElementFactory:Input(opts, placeholder, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Placeholder = placeholder, Callback = callback, EnterPressedOnly = false }
		end
		opts = opts or {}
		local el = Shared.Components.Input.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	function ElementFactory:Label(opts, icon)
		if type(opts) == "string" then
			opts = { Title = opts, Icon = icon }
		end
		opts = opts or {}
		local el = Shared.Components.Label.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title or "")
	end

	function ElementFactory:Paragraph(title, content, icon)
		local opts
		if type(title) == "table" then
			opts = title
		else
			opts = { Title = title, Content = content, Icon = icon }
		end
		local el = Shared.Components.Paragraph.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, (opts.Title or "") .. " " .. (opts.Content or ""))
	end

	-- ``ol.Search`` etc.
	function ElementFactory:DependencyBox()
		return ElementFactory.AddDependencyBox(self)
	end

	function ElementFactory:AddDependencyBox()
		-- Linoria parity stub: simple container section beneath the caller
		local box = {
			Window = self._window,
			Page = self._body or self._page,
			_elements = {},
			_index = 0,
		}
		for k, v in pairs(ElementFactory) do
			box[k] = function(_, ...)
				return v(box, ...)
			end
		end
		return box
	end

	function ElementFactory:Divider(text)
		local opts = type(text) == "table" and text or { Text = text }
		local el = Shared.Components.Divider.New(MakeScope(self, opts.Text), opts)
		return Track(self, el, opts.Text or "")
	end

	function ElementFactory:ProgressBar(opts, value, max)
		if type(opts) == "string" then
			opts = { Title = opts, Value = value, Max = max }
		end
		opts = opts or {}
		local el = Shared.Components.ProgressBar.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title or "")
	end

	function ElementFactory:Image(opts, image, height)
		if type(opts) == "string" then
			opts = { Image = opts, Height = image }
		end
		opts = opts or {}
		local el = Shared.Components.Image.New(MakeScope(self, opts.Title or "image"), opts)
		return Track(self, el, opts.Title or "")
	end

	-- Common aliases (Rayfield / Fluent / Linoria conventions)
	ElementFactory.AddButton = ElementFactory.Button
	ElementFactory.AddToggle = ElementFactory.Toggle
	ElementFactory.AddSlider = ElementFactory.Slider
	ElementFactory.AddDropdown = ElementFactory.Dropdown
	ElementFactory.AddColorPicker = ElementFactory.ColorPicker
	ElementFactory.AddKeybind = ElementFactory.Keybind
	ElementFactory.AddInput = ElementFactory.Input
	ElementFactory.AddLabel = ElementFactory.Label
	ElementFactory.AddParagraph = ElementFactory.Paragraph
	ElementFactory.AddDivider = ElementFactory.Divider
	ElementFactory.AddProgressBar = ElementFactory.ProgressBar
	ElementFactory.AddImage = ElementFactory.Image

	----------------------------------------------------------------------
	-- Section
	----------------------------------------------------------------------

	Section.__index = Section

	-- Containers.Section.New(window, tab, title, opts) -> Section
	-- opts: { Icon, Side ("Left"|"Right"|nil for full-width), Collapsible }
	function Section.New(window, tab, title, opts)
		opts = opts or {}
		local self = setmetatable({}, Section)
		self._window = window
		self._tab = tab
		self._title = title or "Section"
		self._elements = {}
		self._index = 0
		self._fullWidth = opts.Side == nil

		-- outer frame
		local frame = Utility.New("Frame", {
			Name = "Section_" .. self._title,
			BackgroundColor3 = Theme:Get("Card"),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = opts.Parent or tab._page,
		})
		Utility.Round(frame, 10)
		Utility.Stroke(frame, "Stroke", 1, 0.5)
		Utility.Paint(frame, "BackgroundColor3", "Card")

		-- header
		local header = Utility.New("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = frame,
		})
		Utility.Pad(header, 10, 0, 10, 0)

		Utility.New("Frame", { -- accent pip
			Name = "Pip",
			BackgroundColor3 = Theme:Get("Accent"),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 3, 0, 14),
			Parent = header,
		})

		local titleLabel = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = self._title,
			TextColor3 = Theme:Get("Text"),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(1, -40, 1, 0),
			Parent = header,
		})
		Utility.Paint(titleLabel, "TextColor3", "Text")

		local collapseIcon
		if opts.Collapsible then
			collapseIcon = Utility.New("ImageLabel", {
				Name = "Chevron",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				Parent = header,
			})
			Shared.Icons:Apply(collapseIcon, "chevron-down")
			Utility.Paint(collapseIcon, "ImageColor3", "Muted")
		end

		-- body
		local body = Utility.New("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(0, 0, 0, 30),
			Parent = frame,
		})
		Utility.Pad(body, 8, 0, 8, 8)
		local layout = Utility.ListLayout(body, { Padding = 6 })

		self._frame = frame
		self._body = body
		self._page = body -- elements parent into body
		self._header = header
		self._collapsed = false

		-- collapse support
		if opts.Collapsible then
			local btn = Utility.New("TextButton", {
				Name = "CollapseHitbox",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				Parent = header,
			})
			btn.MouseButton1Click:Connect(function()
				self:SetCollapsed(not self._collapsed)
			end)
		end

		return self
	end

	function Section:SetCollapsed(collapsed)
		self._collapsed = collapsed
		local target = collapsed and 30 or (self._body.AbsoluteSize.Y + 38)
		Tween:Play(self._frame, "Snappy", { Size = UDim2.new(1, 0, 0, collapsed and 30 or math.max(target, 30)) })
		if not collapsed then
			-- return to automatic size after the reveal anim completes
			task.delay(0.35, function()
				if not self._collapsed and self._frame.Parent then
					self._frame.AutomaticSize = Enum.AutomaticSize.Y
				end
			end)
		else
			self._frame.AutomaticSize = Enum.AutomaticSize.None
		end
	end

	function Section:SetTitle(text)
		self._title = text
		self._header.Title.Text = text
	end

	function Section:Destroy()
		for _, el in ipairs(self._elements) do
			if el.Destroy then
				pcall(function() el:Destroy() end)
			end
		end
		if self._frame then
			self._frame:Destroy()
		end
	end

	-- Element methods mixed in from ElementFactory
	for k, v in pairs(ElementFactory) do
		Section[k] = v
	end

	----------------------------------------------------------------------
	-- GroupBox â€” a narrower card used for two-column layouts (Linoria side)
	----------------------------------------------------------------------

	GroupBox.__index = GroupBox

	-- Containers.GroupBox.New(window, parentColumn, title, opts)
	function GroupBox.New(window, parentColumn, title, opts)
		opts = opts or {}
		local self = setmetatable({}, GroupBox)
		self._window = window
		self._title = title or "Group"
		self._elements = {}
		self._index = 0

		local frame = Utility.New("Frame", {
			Name = "GroupBox_" .. self._title,
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = parentColumn,
		})
		Utility.Round(frame, 10)
		Utility.Stroke(frame, "Stroke", 1, 0.5)
		Utility.Paint(frame, "BackgroundColor3", "Card")

		-- header with icon support
		local head = Utility.New("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
			Parent = frame,
		})
		Utility.Pad(head, 10, 0, 10, 0)

		if opts.Icon then
			local icon = Utility.New("ImageLabel", {
				Name = "Icon",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				Parent = head,
			})
			Shared.Icons:Apply(icon, opts.Icon)
			Utility.Paint(icon, "ImageColor3", "Accent")
		end

		local titleLabel = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = self._title,
			TextColor3 = Theme:Get("Text"),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, opts.Icon and 20 or 0, 0, 0),
			Size = UDim2.new(1, -(opts.Icon and 20 or 0), 1, 0),
			Parent = head,
		})
		Utility.Paint(titleLabel, "TextColor3", "Text")

		local body = Utility.New("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.new(0, 0, 0, 28),
			Size = UDim2.new(1, 0, 0, 0),
			Parent = frame,
		})
		Utility.Pad(body, 8, 0, 8, 8)
		Utility.ListLayout(body, { Padding = 6 })

		self._frame = frame
		self._body = body
		self._page = body
		return self
	end

	function GroupBox:SetTitle(text)
		self._title = text
		self._frame.Header.Title.Text = text
	end

	function GroupBox:Destroy()
		for _, el in ipairs(self._elements) do
			if el.Destroy then
				pcall(function() el:Destroy() end)
			end
		end
		if self._frame then
			self._frame:Destroy()
		end
	end

	for k, v in pairs(ElementFactory) do
		GroupBox[k] = v
	end

	return { Section = Section, GroupBox = GroupBox, Factory = ElementFactory }
end

end)()

--===========================[ Containers.Tab ]===========================--
__MODULES["Containers.Tab"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Containers/Tab.lua
-- A tab = one sidebar entry + one scrollable content page.
--
--   local Tab = Window:Tab("Main", "home")  -- or Window:CreateTab({...})
--   Tab:Section("Farm")                     -- full-width section
--   Tab:Toggle(...)                         -- element directly on page
--   Tab:AddLeftGroupbox("Aimbot")           -- two-column Linoria-style layout
--   Tab:AddRightGroupbox("Visuals", "eye")
--[[==========================================================================]]

return function(Shared)
	local Tab = {}
	Tab.__index = Tab

	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Containers = Shared.Containers

	-- Tab.New(window, name, icon) -> Tab
	function Tab.New(window, name, iconName)
		local self = setmetatable({}, Tab)
		self._window = window
		self._name = name or "Tab"
		self._icon = iconName
		self._elements = {}
		self._index = 0
		self._layoutOrder = 0
		self._columnRow = nil

		local page = Utility.New("ScrollingFrame", {
			Name = "Page_" .. self._name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme:Get("Muted"),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Visible = false,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			Parent = window._contentHost,
		})
		Utility.Paint(page, "ScrollBarImageColor3", "Muted")
		Utility.Pad(page, 12, 12, 14, 12)
		local layout = Utility.ListLayout(page, { Padding = 10 })
		Utility.ConnectCanvas(page, layout, 14)

		self._page = page
		self._body = page -- sections treat tab page like a body
		return self
	end

	----------------------------------------------------------------------
	-- Creation helpers
	----------------------------------------------------------------------

	local function nextOrder(self)
		self._layoutOrder += 1
		return self._layoutOrder
	end

	-- Tab:Section("Name") | Tab:Section("Name", { Icon, Collapsible, Side })
	function Tab:CreateSection(title, opts)
		local section = Containers.Section.New(self._window, self, title, opts)
		section._frame.LayoutOrder = nextOrder(self)
		return section
	end
	Tab.AddSection = Tab.CreateSection

	-- Legacy v1: Tabs double as sections (elements go straight to page)
	Tab.Section = Tab.CreateSection

	----------------------------------------------------------------------
	-- GroupBox columns (Linoria-style side-by-side)
	----------------------------------------------------------------------

	function Tab:_columns()
		if self._columnRow then
			return self._columnRow
		end
		local row = Utility.New("Frame", {
			Name = "Columns",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = nextOrder(self),
			Parent = self._page,
		})
		Utility.ListLayout(row, { Direction = "Horizontal", Padding = 10 })

		local function column(name)
			local col = Utility.New("Frame", {
				Name = name,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(0.5, -5, 0, 0),
				Parent = row,
			})
			Utility.ListLayout(col, { Padding = 10 })
			return col
		end

		self._columnRow = {
			Frame = row,
			Left = column("Left"),
			Right = column("Right"),
		}
		return self._columnRow
	end

	function Tab:AddLeftGroupbox(title, icon)
		local cols = self:_columns()
		local box = Containers.GroupBox.New(self._window, cols.Left, title, { Icon = icon })
		box._tab = self
		return box
	end

	function Tab:AddRightGroupbox(title, icon)
		local cols = self:_columns()
		local box = Containers.GroupBox.New(self._window, cols.Right, title, { Icon = icon })
		box._tab = self
		return box
	end

	-- Rayfield-ish alias
	Tab.LeftGroupBox = Tab.AddLeftGroupbox
	Tab.RightGroupBox = Tab.AddRightGroupbox

	----------------------------------------------------------------------
	-- Tab state / cleanup
	----------------------------------------------------------------------

	function Tab:SetVisible(visible)
		self._page.Visible = visible
	end

	function Tab:Destroy()
		for _, el in ipairs(self._elements) do
			if el.Destroy then
				pcall(function()
					el:Destroy()
				end)
			end
		end
		if self._page then
			self._page:Destroy()
		end
	end

	-- Elements can live directly on the tab page (v1 style: Tab:Toggle(...))
	-- by mixing in the element factory.
	local factory = Containers.Factory
	for k, v in pairs(factory) do
		Tab[k] = v
	end

	return Tab
end

end)()

--===========================[ Containers.Window ]===========================--
__MODULES["Containers.Window"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Containers/Window.lua
-- The window: topbar, sidebar (tabs + search + user card), content host,
-- popup/dialog layers, restore pill, drag/resize, global toggle key,
-- optional loading splash + key system + watermark + settings tab.
--[[==========================================================================]]

return function(Shared)
	local WindowClass = {}
	WindowClass.__index = WindowClass

	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons
	local Config = Shared.Config
	local Services = Shared.Services

	----------------------------------------------------------------------
	-- Construction
	----------------------------------------------------------------------

	function WindowClass.New(shared, opts)
		opts = opts or {}
		local Self = setmetatable({}, WindowClass)

		Self.Options = opts
		Self.Title = opts.Title or "Tracium"
		Self.Subtitle = opts.Subtitle or ""
		Self.Tabs = {}
		Self.TabOrder = {}
		Self.SelectedTab = nil
		Self.Flags = Shared.Library.Flags
		Self.Open = true
		Self._elements = {}
		Self._popups = {}
		Self._maid = Utility.Maid()
		Self._toggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
		if type(Self._toggleKey) == "string" then
			Self._toggleKey = Utility.KeyFromName(Self._toggleKey) or Enum.KeyCode.RightShift
		end

		Config.Folder = opts.ConfigFolder or opts.FolderName or "Tracium"

		-- -- screen gui ---------------------------------------------------
		local gui = Utility.New("ScreenGui", {
			Name = "TraciumWin_" .. Utility.UID(),
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = 900,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
		Utility.ProtectGui(gui)
		Self.Gui = gui

		-- -- acrylic ------------------------------------------------------
		Self._acrylicAttached = false
		if opts.Acrylic ~= false then
			Self._acrylicAttached = Shared.Acrylic:Attach()
		end

		-- -- window frame --------------------------------------------------
		local size = opts.Size or UDim2.fromOffset(720, 540)
		if typeof(size) == "Vector2" then
			size = UDim2.fromOffset(size.X, size.Y)
		end
		Self.Size = size

		local root = Utility.New("Frame", {
			Name = "Root",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = size,
			BackgroundColor3 = Theme:Get("Background"),
			BackgroundTransparency = (opts.Acrylic ~= false and Self._acrylicAttached) and 0.05 or 0,
			ClipsDescendants = true,
			Parent = gui,
		})
		Utility.Paint(root, "BackgroundColor3", "Background")
		Utility.Round(root, 14)
		Utility.Stroke(root, "Stroke", 1, 0.35)
		Self.Root = root

		-- layered soft shadows
		for i, t in ipairs({ 0.82, 0.68, 0.55 }) do
			local sh = Utility.New("Frame", {
				Name = "Shadow" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 22 + i * 16, 1, 22 + i * 16),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = t,
				ZIndex = -i,
				Parent = root,
			})
			Utility.Round(sh, 20 + i * 3)
		end

		-- size constraints + global ui scale
		local minSize = opts.MinSize or UDim2.fromOffset(480, 360)
		Utility.New("UISizeConstraint", {
			MinSize = Vector2.new(minSize.X.Offset, minSize.Y.Offset),
			Parent = root,
		})
		Self._scale = Utility.New("UIScale", { Scale = opts.UIScale or 1, Parent = root })

		-- intro animation
		Self._scale.Scale = (opts.UIScale or 1) * 0.94
		Tween:Play(Self._scale, "Spring", { Scale = opts.UIScale or 1 })

		-- loading splash (optional): dims the window content until done
		if opts.LoadingEnabled then
			local splash = Utility.New("Frame", {
				Name = "LoadingSplash",
				BackgroundColor3 = Theme:Get("Background"),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 90,
				Visible = true,
				Parent = root,
			})
			Utility.Paint(splash, "BackgroundColor3", "Background")

			local spinner = Icons:Create("loader", {
				Name = "Spinner", Size = 34, Color = "Accent",
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Parent = splash,
			})
			local stopSpin = Tween:Spin(spinner, 1.1)

			local lt = Utility.New("TextLabel", {
				BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16,
				TextColor3 = Theme:Get("Text"), Text = opts.LoadingTitle or Self.Title,
				Position = UDim2.new(0, 0, 0, 84), Size = UDim2.new(1, 0, 0, 20), ZIndex = 91,
				Parent = splash,
			})
			Utility.Paint(lt, "TextColor3", "Text")
			local ls = Utility.New("TextLabel", {
				BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
				TextColor3 = Theme:Get("SubText"), Text = opts.LoadingSubtitle or "loading modules...",
				Position = UDim2.new(0, 0, 0, 108), Size = UDim2.new(1, 0, 0, 16), ZIndex = 91,
				Parent = splash,
			})
			Utility.Paint(ls, "TextColor3", "SubText")

			task.delay(1.2, function()
				if not splash.Parent then
					return
				end
				stopSpin()
				Tween:Play(splash, "Fade", { GroupTransparency = 1 })
				-- GroupTransparency only exists on CanvasGroup; fade via children instead
				Tween:Play(spinner, "Fast", { ImageTransparency = 1 })
				Tween:Play(lt, "Fast", { TextTransparency = 1 })
				Tween:Play(ls, "Fast", { TextTransparency = 1 })
				Tween:Play(splash, "Fast", { BackgroundTransparency = 1 })
				task.delay(0.3, function()
					if splash.Parent then
						splash:Destroy()
					end
				end)
			end)
		end

		-- key system (optional hard gate)
		if opts.KeySystem and type(opts.KeySystem) == "table" and opts.KeySystem.Enabled ~= false then
			local ks = opts.KeySystem
			local gate = Utility.New("Frame", {
				Name = "KeySystem",
				BackgroundColor3 = Theme:Get("Background"),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 95,
				Visible = true,
				Parent = root,
			})
			Utility.Paint(gate, "BackgroundColor3", "Background")

			local panel = Utility.New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, 300, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme:Get("Surface"),
				ZIndex = 96,
				Parent = gate,
			})
			Utility.Paint(panel, "BackgroundColor3", "Surface")
			Utility.Round(panel, 12)
			Utility.Stroke(panel, "StrokeHover", 1, 0.35)
			Utility.Pad(panel, 18, 16, 18, 16)

			local plist = Utility.New("Frame", {
				BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0), Parent = panel,
			})
			Utility.ListLayout(plist, { Padding = 8 })

			Utility.New("TextLabel", {
				BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 15,
				TextColor3 = Theme:Get("Text"), Text = ks.Title or (Self.Title .. " â€” Key Required"),
				Size = UDim2.new(1, 0, 0, 20), ZIndex = 97, Parent = plist,
			})

			if ks.Subtitle and ks.Subtitle ~= "" then
				Utility.New("TextLabel", {
					BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
					TextColor3 = Theme:Get("SubText"), TextWrapped = true,
					Text = ks.Subtitle, AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 0), ZIndex = 97, Parent = plist,
				})
			end

			local keyField = Utility.New("Frame", {
				BackgroundColor3 = Theme:Get("Input"), Size = UDim2.new(1, 0, 0, 32), ZIndex = 97, Parent = plist,
			})
			Utility.Paint(keyField, "BackgroundColor3", "Input")
			Utility.Round(keyField, 8)
			local keyBox = Utility.New("TextBox", {
				BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13,
				TextColor3 = Theme:Get("Text"), PlaceholderText = ks.Placeholder or "enter key...",
				PlaceholderColor3 = Theme:Get("Muted"), Text = "",
				Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0),
				ClearTextOnFocus = false, ZIndex = 98, Parent = keyField,
			})
			Utility.Paint(keyBox, "TextColor3", "Text")
			Utility.Paint(keyBox, "PlaceholderColor3", "Muted")

			local getKeyBtn
			if ks.GetKeyLabel and ks.GetKeyURL then
				getKeyBtn = Utility.New("TextButton", {
					BackgroundColor3 = Theme:Get("Card"), Font = Enum.Font.GothamMedium, TextSize = 11,
					TextColor3 = Theme:Get("SubText"), Text = ks.GetKeyLabel, AutoButtonColor = false,
					Size = UDim2.new(1, 0, 0, 24), ZIndex = 97, Parent = plist,
				})
				Utility.Paint(getKeyBtn, "BackgroundColor3", "Card")
				Utility.Round(getKeyBtn, 7)
				getKeyBtn.MouseButton1Click:Connect(function()
					if setclipboard then
						pcall(setclipboard, tostring(ks.GetKeyURL))
					end
					Shared.Notify:Notify({ Title = "Key link copied", Content = tostring(ks.GetKeyURL), Duration = 3 })
				end)
			end

			local submitBtn = Utility.New("TextButton", {
				BackgroundColor3 = Theme:Get("Accent"), Font = Enum.Font.GothamBold, TextSize = 13,
				TextColor3 = Theme:Get("AccentText"), Text = ks.SubmitLabel or "Unlock",
				AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 30), ZIndex = 97, Parent = plist,
			})
			Utility.Paint(submitBtn, "BackgroundColor3", "Accent")
			Utility.Paint(submitBtn, "TextColor3", "AccentText")
			Utility.Round(submitBtn, 8)

			local statusLab = Utility.New("TextLabel", {
				BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
				TextColor3 = Theme:Get("Danger"), Text = "", Size = UDim2.new(1, 0, 0, 14),
				ZIndex = 97, Visible = false, Parent = plist,
			})

			local function checkKey()
				if ks.Validate then
					local ok, res = pcall(ks.Validate, keyBox.Text)
					return ok and res == true
				end
				for _, k in ipairs(ks.Keys or {}) do
					if tostring(k) == keyBox.Text then
						return true
					end
				end
				return false
			end

			local function tryUnlock()
				if checkKey() then
					statusLab.Visible = false
					Tween:Play(gate, "Fade", { BackgroundTransparency = 1 })
					Tween:Play(panel, "Fade", { BackgroundTransparency = 1 })
					task.delay(0.25, function()
						if gate.Parent then gate:Destroy() end
					end)
					Shared.Notify:Notify({ Title = "Access granted", Content = "Welcome back.", Type = "Success", Duration = 2 })
				else
					statusLab.Text = ks.FailMessage or "Invalid key"
					statusLab.Visible = true
					Tween:Play(panel, "Fast", { Position = UDim2.fromScale(0.5, 0.502) })
					task.delay(0.05, function()
						Tween:Play(panel, "Fast", { Position = UDim2.fromScale(0.5, 0.5) })
					end)
				end
			end
			submitBtn.MouseButton1Click:Connect(tryUnlock)
			keyBox.FocusLost:Connect(function(enter)
				if enter then tryUnlock() end
			end)
		end

		----------------------------------------------------------------
		-- Topbar
		----------------------------------------------------------------
		local topbar = Utility.New("Frame", {
			Name = "Topbar",
			BackgroundColor3 = Theme:Get("Surface"),
			BackgroundTransparency = 0.15,
			Size = UDim2.new(1, 0, 0, 46),
			Parent = root,
		})
		Utility.Paint(topbar, "BackgroundColor3", "Surface")

		Utility.New("Frame", { -- accent underline
			Name = "AccentLine",
			BackgroundColor3 = Theme:Get("Accent"),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			Parent = topbar,
		})

		-- logo
		local logo = Utility.New("Frame", {
			Name = "Logo",
			BackgroundColor3 = Theme:Get("Accent"),
			Position = UDim2.new(0, 14, 0.5, -13),
			Size = UDim2.fromOffset(26, 26),
			Parent = topbar,
		})
		Utility.Round(logo, 7)
		Utility.Gradient(logo, "Accent", "Accent2", 135)
		Icons:Create(opts.Icon or "zap", {
			Size = 15, Color = Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = logo,
		})

		local titleLabel = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 48, 0, 6),
			Size = UDim2.new(1, -240, 0, 18),
			Text = Self.Title,
			Parent = topbar,
		})
		Utility.Paint(titleLabel, "TextColor3", "Text")

		local subLabel = Utility.New("TextLabel", {
			Name = "Subtitle",
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextColor3 = Theme:Get("SubText"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 48, 0, 24),
			Size = UDim2.new(1, -240, 0, 14),
			Text = Self.Subtitle,
			Parent = topbar,
		})
		Utility.Paint(subLabel, "TextColor3", "SubText")

		-- tag chip
		local function endChip(text, xOffset, tooltipText)
			local chip = Utility.New("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, xOffset, 0.5, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 0, 20),
				BackgroundColor3 = Theme:Get("Card"),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextColor3 = Theme:Get("Accent"),
				Text = "  " .. text .. "  ",
				Parent = topbar,
			})
			Utility.Paint(chip, "BackgroundColor3", "Card")
			Utility.Paint(chip, "TextColor3", "Accent")
			Utility.Round(chip, 6)
			Utility.Stroke(chip, "Accent", 1, 0.6)
			if tooltipText then
				Shared.Tooltip:Attach(chip, tooltipText)
			end
			return chip
		end

		local rightOffset = -50
		if opts.Tag then
			endChip(opts.Tag, rightOffset)
			rightOffset -= 90
		end

		-- close + minimize icon buttons
		local function topIcon(iconName, xOffset, tint)
			local btn = Utility.New("TextButton", {
				Name = "TopBtn_" .. iconName,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, xOffset, 0.5, 0),
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = Theme:Get("Card"),
				BackgroundTransparency = 0.4,
				Text = "",
				AutoButtonColor = false,
				Parent = topbar,
			})
			Utility.Round(btn, 6)
			local img = Icons:Create(iconName, {
				Size = 12, Color = tint or "SubText",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Parent = btn,
			})
			btn.MouseEnter:Connect(function()
				Tween:Play(btn, "Fast", { BackgroundTransparency = 0 })
				Tween:Play(img, "Fast", { ImageColor3 = Theme:Get("Text") })
			end)
			btn.MouseLeave:Connect(function()
				Tween:Play(btn, "Fast", { BackgroundTransparency = 0.4 })
				Tween:Play(img, "Fast", { ImageColor3 = Theme:Get(tint or "SubText") })
			end)
			return btn
		end

		local closeBtn = topIcon("x", -12, "Danger")
		local minBtn = topIcon("minus", -40)

		closeBtn.MouseButton1Click:Connect(function()
			Self:Destroy()
		end)

		----------------------------------------------------------------
		-- Sidebar
		----------------------------------------------------------------
		local SIDE_W = 186

		local sidebar = Utility.New("Frame", {
			Name = "Sidebar",
			BackgroundColor3 = Theme:Get("Sidebar"),
			BackgroundTransparency = 0.05,
			Position = UDim2.new(0, 0, 0, 47),
			Size = UDim2.new(0, SIDE_W, 1, -47),
			Parent = root,
		})
		Utility.Paint(sidebar, "BackgroundColor3", "Sidebar")

		Utility.New("Frame", { -- right divider
			BackgroundColor3 = Theme:Get("Divider"),
			BorderSizePixel = 0,
			Position = UDim2.new(1, -1, 0, 0),
			Size = UDim2.new(0, 1, 1, 0),
			Parent = sidebar,
		})

		-- search
		local searchEnabled = opts.Search ~= false
		local searchWrap
		if searchEnabled then
			searchWrap = Utility.New("Frame", {
				Name = "Search",
				BackgroundColor3 = Theme:Get("Input"),
				Position = UDim2.new(0, 10, 0, 10),
				Size = UDim2.new(1, -20, 0, 30),
				Parent = sidebar,
			})
			Utility.Paint(searchWrap, "BackgroundColor3", "Input")
			Utility.Round(searchWrap, 8)
			Utility.Stroke(searchWrap, "Stroke", 1, 0.55)

			Icons:Create("search", {
				Size = 13, Color = "Muted",
				Position = UDim2.new(0, 9, 0.5, -6),
				Parent = searchWrap,
			})

			local box = Utility.New("TextBox", {
				Name = "Box",
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextColor3 = Theme:Get("Text"),
				PlaceholderText = "Search settings...",
				PlaceholderColor3 = Theme:Get("Muted"),
				Text = "",
				ClearTextOnFocus = false,
				Position = UDim2.new(0, 30, 0, 0),
				Size = UDim2.new(1, -36, 1, 0),
				Parent = searchWrap,
			})
			Utility.Paint(box, "TextColor3", "Text")
			Utility.Paint(box, "PlaceholderColor3", "Muted")
			Self._searchBox = box
		end

		-- tab list
		local tabList = Utility.New("ScrollingFrame", {
			Name = "Tabs",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 8, 0, searchEnabled and 50 or 12),
			Size = UDim2.new(1, -16, 1, searchEnabled and -110 or -70),
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Theme:Get("Muted"),
			Parent = sidebar,
		})
		Utility.Paint(tabList, "ScrollBarImageColor3", "Muted")
		local tabLayout = Utility.ListLayout(tabList, { Padding = 4 })
		Utility.ConnectCanvas(tabList, tabLayout, 4)

		-- user card
		if opts.UserInfo ~= false then
			local card = Utility.New("Frame", {
				Name = "User",
				BackgroundColor3 = Theme:Get("Card"),
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 10, 1, -10),
				Size = UDim2.new(1, -20, 0, 46),
				Parent = sidebar,
			})
			Utility.Paint(card, "BackgroundColor3", "Card")
			Utility.Round(card, 10)
			Utility.Stroke(card, "Stroke", 1, 0.55)

			local avatar = Utility.New("ImageLabel", {
				Name = "Avatar",
				BackgroundColor3 = Theme:Get("Element"),
				Position = UDim2.new(0, 8, 0.5, -15),
				Size = UDim2.fromOffset(30, 30),
				Parent = card,
			})
			Utility.Round(avatar, 15)
			Utility.Stroke(avatar, "Accent", 1.5, 0.4)
			task.spawn(function()
				local lp = Services.LocalPlayer
				if lp then
					local ok, thumb = pcall(function()
						return Services.Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
					end)
					if ok and thumb then
						avatar.Image = thumb
					end
				end
			end)

			local info = opts.UserInfo
			local displayName = type(info) == "table" and info.Name
				or (Services.LocalPlayer and (Services.LocalPlayer.DisplayName or Services.LocalPlayer.Name) or "Player")
			local nameLab = Utility.New("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = Theme:Get("Text"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.new(0, 46, 0, 8),
				Size = UDim2.new(1, -52, 0, 15),
				Text = displayName,
				Parent = card,
			})
			Utility.Paint(nameLab, "TextColor3", "Text")

			local subTxt = type(info) == "table" and info.SubTitle
				or (Services.LocalPlayer and ("@" .. Services.LocalPlayer.Name)) or ""
			local subLab = Utility.New("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 10,
				TextColor3 = Theme:Get("Muted"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.new(0, 46, 0, 24),
				Size = UDim2.new(1, -52, 0, 13),
				Text = subTxt,
				Parent = card,
			})
			Utility.Paint(subLab, "TextColor3", "Muted")
		end

		-- brand footer
		Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 9,
			TextColor3 = Theme:Get("Muted"),
			Text = "TRACIUM v" .. Shared.Version,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -4 - (opts.UserInfo ~= false and 48 or 0)),
			Size = UDim2.new(1, -24, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = sidebar,
			Name = "Brand",
		})

		----------------------------------------------------------------
		-- Content host
		----------------------------------------------------------------
		local contentHost = Utility.New("Frame", {
			Name = "Content",
			BackgroundColor3 = Theme:Get("Inset"),
			BackgroundTransparency = 0.35,
			Position = UDim2.new(0, SIDE_W, 0, 47),
			Size = UDim2.new(1, -SIDE_W, 1, -47),
			Parent = root,
		})
		Utility.Paint(contentHost, "BackgroundColor3", "Inset")
		Self._contentHost = contentHost

		----------------------------------------------------------------
		-- Popup layer + click catcher
		----------------------------------------------------------------
		local popupLayer = Utility.New("Frame", {
			Name = "PopupLayer",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 40,
			Parent = root,
		})

		local catcher = Utility.New("TextButton", {
			Name = "Catcher",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 39,
			AutoButtonColor = false,
			Parent = popupLayer,
		})
		catcher.MouseButton1Click:Connect(function()
			Self:ClosePopups()
		end)
		Self.PopupLayer = popupLayer

		-- dialog overlay origin
		local dialogHost = Utility.New("Frame", {
			Name = "DialogHost",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = true,
			ZIndex = 50,
			Parent = root,
		})
		Self.DialogHost = dialogHost

		function Self:OpenPopupHandle(frame, closeFn)
			popupLayer.Visible = true
			frame.Parent = popupLayer
			self._popups[frame] = closeFn or true
		end

		function Self:ClosePopups()
			for frame, closeFn in pairs(self._popups) do
				if type(closeFn) == "function" then
					pcall(closeFn)
				end
				if frame and frame.Parent then
					frame.Parent = nil
				end
			end
			table.clear(self._popups)
			popupLayer.Visible = false
		end

		----------------------------------------------------------------
		-- Dragging + resize
		----------------------------------------------------------------
		Self._maid:Give(Shared.Drag:MakeDraggable(topbar, root, {
			Bounds = true,
			Lerp = 0.35,
		}))

		if opts.Resizable ~= false then
			local grip = Utility.New("TextButton", {
				Name = "ResizeGrip",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -2, 1, -2),
				Size = UDim2.fromOffset(18, 18),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 46,
				Parent = root,
			})
			local gripIcon = Icons:Create("resize-bottom-right", {
				Size = 12, Color = "Muted",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Parent = grip,
			})
			if not Icons.Exists("resize-bottom-right") then
				Icons:Apply(gripIcon, "maximize-2")
				gripIcon.Rotation = 90
			end
			local resizing = false
			local startSize, startInput
			grip.InputBegan:Connect(function(input)
				if Utility.IsClick(input) then
					resizing = true
					startSize = root.Size
					startInput = input.Position
				end
			end)
			Self._maid:Give(Services.UserInputService.InputChanged:Connect(function(input)
				if resizing and Utility.IsMove(input) then
					local delta = Vector2.new(input.Position.X - startInput.X, input.Position.Y - startInput.Y)
					root.Size = UDim2.new(0, math.max(startSize.X.Offset + delta.X, 480), 0, math.max(startSize.Y.Offset + delta.Y, 340))
				end
			end))
			Self._maid:Give(Services.UserInputService.InputEnded:Connect(function(input)
				if Utility.IsClick(input) then
					resizing = false
				end
			end))
		end

		----------------------------------------------------------------
		-- Toggle key + restore pill
		----------------------------------------------------------------
		local pill = Utility.New("TextButton", {
			Name = "RestorePill",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 16, 1, -16),
			Size = UDim2.new(0, 160, 0, 38),
			BackgroundColor3 = Theme:Get("Surface"),
			Visible = false,
			Text = "",
			AutoButtonColor = false,
			Parent = gui,
		})
		Utility.Paint(pill, "BackgroundColor3", "Surface")
		Utility.Round(pill, 12)
		Utility.Stroke(pill, "Accent", 1.5, 0.3)
		Utility.Pad(pill, 10, 0, 10, 0)

		local pillDot = Utility.New("Frame", {
			BackgroundColor3 = Theme:Get("Accent"),
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new(0, 6, 0.5, -7),
			Parent = pill,
		})
		Utility.Round(pillDot, 7)
		Utility.Gradient(pillDot, "Accent", "Accent2", 135)

		Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			Text = Self.Title,
			Position = UDim2.new(0, 28, 0, 0),
			Size = UDim2.new(1, -28, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = pill,
		})
		Self._pill = pill

		Shared.Drag:MakeDraggable(pill, pill, { Lerp = 0.45 })
		pill.MouseButton1Click:Connect(function()
			Self:Show()
		end)

		Self._maid:Give(Services.UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe or Utility.IsTyping() then
				return
			end
			if Self._toggleKey and input.KeyCode == Self._toggleKey then
				Self:Toggle()
			end
		end))

		----------------------------------------------------------------
		-- Watermark
		----------------------------------------------------------------
		if opts.Watermark and opts.Watermark.Enabled ~= false then
			Self:_createWatermark(opts.Watermark)
		end

		----------------------------------------------------------------
		-- Tab registry + helpers
		----------------------------------------------------------------
		Self._tabList = tabList
		Self._sidebar = sidebar

		-- register element for cross-tab search
		function Self:_registerElement(element, searchText, section)
			table.insert(Self._elements, {
				Element = element,
				Search = (searchText or ""):lower(),
				Section = section,
				Tab = section and section._tab,
			})
		end

		-- search filtering (hides/shows elements & dims tabs without matches)
		if searchEnabled then
			local searchBox = Self._searchBox
			local function applyFilter(q)
				q = (q or ""):lower()
				local tabHasMatch = {}
				for _, entry in ipairs(Self._elements) do
					local match = q == "" or entry.Search:find(q, 1, true) ~= nil
					if entry.Element and entry.Element.Root and entry.Element.Root.Parent then
						entry.Element.Root.Visible = match
					end
					if match and entry.Tab then
						tabHasMatch[entry.Tab._name] = true
					end
				end
				-- dim tabs with zero matches
				for _, tab in ipairs(Self.TabOrder) do
					local btn = tab._button
					if btn then
						local dimmed = q ~= "" and not tabHasMatch[tab._name]
						Tween:Play(btn, "Fast", { TextTransparency = dimmed and 0.6 or 0 })
					end
				end
				-- jump to first matching tab
				if q ~= "" and Self.SelectedTab and not tabHasMatch[Self.SelectedTab._name] then
					for _, tab in ipairs(Self.TabOrder) do
						if tabHasMatch[tab._name] then
							Self:SelectTab(tab._name)
							break
						end
					end
				end
			end
			searchBox:GetPropertyChangedSignal("Text"):Connect(function()
				applyFilter(searchBox.Text)
			end)
			Self._applyFilter = applyFilter
		end

		----------------------------------------------------------------
		-- Tabs
		----------------------------------------------------------------
		local tabButtons = {}

		function Self:Tab(name, iconName)
			if type(name) == "table" then
				iconName = name.Icon or name.Image
				name = name.Title or name.Name
			end
			name = tostring(name or "Tab")

			local tab = Shared.Containers.Tab.New(Self, name, iconName)

			-- sidebar button
			local btn = Utility.New("TextButton", {
				Name = "TabBtn_" .. name,
				BackgroundColor3 = Theme:Get("Sidebar"),
				Size = UDim2.new(1, 0, 0, 32),
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = #Self.TabOrder + 1,
				Parent = Self._tabList,
			})
			Utility.Round(btn, 8)

			local indicator = Utility.New("Frame", {
				Name = "Indicator",
				BackgroundColor3 = Theme:Get("Accent"),
				Position = UDim2.new(0, 0, 0.25, 0),
				Size = UDim2.new(0, 3, 0.5, 0),
				BackgroundTransparency = 1,
				Parent = btn,
			})
			Utility.Round(indicator, 2)

			if iconName then
				Icons:Create(iconName, {
					Size = 14, Color = "SubText",
					Position = UDim2.new(0, 12, 0.5, -7),
					Parent = btn, Name = "Icon",
				})
			end

			local label = Utility.New("TextLabel", {
				Name = "Label",
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = Theme:Get("SubText"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.new(0, iconName and 34 or 14, 0, 0),
				Size = UDim2.new(1, iconName and -40 or -20, 1, 0),
				Text = name,
				Parent = btn,
			})

			btn.MouseButton1Click:Connect(function()
				Self:SelectTab(name)
			end)
			btn.MouseEnter:Connect(function()
				if Self.SelectedTab ~= tab then
					Tween:Play(btn, "Fast", { BackgroundColor3 = Theme:Get("Card") })
				end
			end)
			btn.MouseLeave:Connect(function()
				if Self.SelectedTab ~= tab then
					Tween:Play(btn, "Fast", { BackgroundColor3 = Theme:Get("Sidebar") })
				end
			end)

			tab._button = btn
			tab._btnLabel = label
			tab._btnIcon = btn:FindFirstChild("Icon")
			tab._btnIndicator = indicator
			tabButtons[name] = tab

			table.insert(Self.Tabs, tab)
			table.insert(Self.TabOrder, tab)

			if #Self.TabOrder == 1 then
				Self:SelectTab(name)
			end
			return tab
		end
		Self.CreateTab = Self.Tab

		function Self:SelectTab(nameOrIndex)
			local target
			if type(nameOrIndex) == "number" then
				target = Self.TabOrder[nameOrIndex]
			else
				target = tabButtons[nameOrIndex]
			end
			if not target then
				return
			end

			for _, tab in ipairs(Self.TabOrder) do
				local active = tab == target
				tab._page.Visible = active
				if active then
					tab._page.Position = UDim2.new(0, 0, 0, 6)
					Tween:Play(tab._page, "TabSwitch", { Position = UDim2.new(0, 0, 0, 0) })
				end
				if tab._button then
					Tween:Play(tab._button, "Fast", {
						BackgroundColor3 = active and Theme:Get("Card") or Theme:Get("Sidebar"),
					})
					if tab._btnLabel then
						Tween:Play(tab._btnLabel, "Fast", {
							TextColor3 = active and Theme:Get("Text") or Theme:Get("SubText"),
						})
					end
					if tab._btnIcon then
						Tween:Play(tab._btnIcon, "Fast", {
							ImageColor3 = active and Theme:Get("Accent") or Theme:Get("SubText"),
						})
					end
					if tab._btnIndicator then
						Tween:Play(tab._btnIndicator, "Fast", {
							BackgroundTransparency = active and 0 or 1,
						})
					end
				end
			end

			Self.SelectedTab = target
			Self:ClosePopups()
			if Self._applyFilter and Self._searchBox and Self._searchBox.Text ~= "" then
				Self._applyFilter(Self._searchBox.Text)
			end
		end

		----------------------------------------------------------------
		-- Private helpers (defined on the class below so methods work
		-- even for the first-created window)
		----------------------------------------------------------------

		-- open state
		function Self:Show()
			if Self.Open then return end
			Self.Open = true
			root.Visible = true
			pill.Visible = false
			Self._scale.Scale = (opts.UIScale or 1) * 0.95
			Tween:Play(Self._scale, "Spring", { Scale = opts.UIScale or 1 })
			if Self._acrylicAttached then
				Shared.Acrylic:SetEnabled(true)
			end
			for _, cb in ipairs(Self._onShow) do task.spawn(cb) end
		end

		function Self:Hide()
			if not Self.Open then return end
			Self.Open = false
			Self:ClosePopups()
			Tween:Play(Self._scale, "Fast", { Scale = (opts.UIScale or 1) * 0.96 })
			task.delay(0.12, function()
				root.Visible = false
				pill.Visible = true
			end)
			-- tab button hover fix
			if Self._acrylicAttached then
				Shared.Acrylic:SetEnabled(false)
			end
			for _, cb in ipairs(Self._onHide) do task.spawn(cb) end
		end

		function Self:Toggle()
			if Self.Open then
				Self:Hide()
			else
				Self:Show()
			end
		end

		Self._onShow, Self._onHide = {}, {}
		function Self:OnShow(fn) table.insert(Self._onShow, fn) end
		function Self:OnHide(fn) table.insert(Self._onHide, fn) end

		function Self:Minimize()
			Self:Hide()
		end

		-- center in viewport
		function Self:Center()
			local cam = Services.Workspace.CurrentCamera
			if cam then
				root.AnchorPoint = Vector2.new(0.5, 0.5)
				root.Position = UDim2.fromScale(0.5, 0.5)
			end
		end

		-- config passthrough
		function Self:Save() Config:Save() end
		function Self:SaveAs(name) Config:Save(name) end
		function Self:Load() Config:Load() end
		function Self:DeleteConfig(name) Config:Delete(name) end
		function Self:ConfigList() return Config:List() end

		function Self:Notify(nopts)
			return Shared.Notify:Notify(nopts)
		end

		function Self:SetTheme(name)
			return Theme:Set(name)
		end

		function Self:GetTheme()
			return Theme.Current
		end

		function Self:SetTitle(text)
			Self.Title = tostring(text)
			local tl = Self.Root and Self.Root:FindFirstChild("Topbar") and Self.Root.Topbar:FindFirstChild("Title")
			if tl then
				tl.Text = Self.Title
			end
		end

		function Self:Dialog(dopts)
			return Shared.Components.Dialog.Open(Self, dopts)
		end

		-- destroy everything
		function Self:Destroy()
			if not Self.Gui or not Self.Gui.Parent then return end
			Self:ClosePopups()
			for _, tab in ipairs(Self.TabOrder) do
				tab:Destroy()
			end
			Self._maid:Clean()
			if Self._watermarkConn then Self._watermarkConn:Disconnect() end
			if Self._watermark then Self._watermark:Destroy() end
			if Self._acrylicAttached then Shared.Acrylic:Release() end
			Tween:Play(Self._scale, "Fast", { Scale = (opts.UIScale or 1) * 0.92 })
			task.delay(0.15, function()
				if Self.Gui then Self.Gui:Destroy() end
			end)
			for i, w in ipairs(Shared.Library.Windows) do
				if w == Self then table.remove(Shared.Library.Windows, i) break end
			end
		end

		-- first-run config autoload
		if opts.ConfigName then
			Config.ActiveProfile = Config.SanitizeName(opts.ConfigName)
		end
		if opts.AutoLoadConfig ~= false and Config.ActiveProfile then
			Config:Load(Config.ActiveProfile)
		else
			local auto = Config:GetAutoload()
			if auto then
				Config:Load(auto)
			end
		end

		-- auto settings tab
		if opts.SettingsTab ~= false or opts.SettingsTab == nil then
			Self:CreateSettingsTab()
		end

		Shared.Notify:Notify({
			Title = Self.Title,
			Content = ("Loaded Â· Tracium v%s"):format(Shared.Version),
			Type = "Info",
			Duration = 3,
		})

		return Self
	end

	----------------------------------------------------------------------
	-- Watermark (draggable top-center FPS/Ping/Time pill)
	----------------------------------------------------------------------
	function WindowClass:_createWatermark(wopts)
		wopts = wopts or {}
		local showFPS = wopts.ShowFPS ~= false
		local showPing = wopts.ShowPing ~= false
		local showTime = wopts.ShowTime ~= false

		local wm = Utility.New("TextButton", {
			Name = "TraciumWatermark",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.new(0, 240, 0, 26),
			BackgroundColor3 = Theme:Get("Surface"),
			BackgroundTransparency = 0.06,
			Text = "",
			AutoButtonColor = false,
			Parent = Self.Gui,
		})
		Utility.Round(wm, 13)
		Utility.Stroke(wm, "Stroke", 1, 0.45)
		Utility.Paint(wm, "BackgroundColor3", "Surface")

		local label = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Theme:Get("Text"),
			Size = UDim2.fromScale(1, 1),
			Text = "TRACIUM",
			Parent = wm,
		})
		Utility.Paint(label, "TextColor3", "Text")

		Shared.Drag:MakeDraggable(wm, wm, { Lerp = 0.5 })

		local lastDt = 1 / 60
		local fps = 60
		local conn = Services.RunService.RenderStepped:Connect(function(dt)
			lastDt = dt
		end)
		Self._watermarkConn = conn

		task.spawn(function()
			while wm.Parent do
				fps = math.floor(1 / math.max(lastDt, 1e-5) + 0.5)
				local parts = { "TRACIUM" }
				if showFPS then
					table.insert(parts, fps .. " fps")
				end
				if showPing then
					local ok, ping = pcall(function()
						return math.floor(Services.Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
					end)
					if ok and ping then
						table.insert(parts, ping .. " ms")
					end
				end
				if showTime then
					table.insert(parts, os.date("%H:%M:%S"))
				end
				label.Text = table.concat(parts, "  Â·  ")
				task.wait(0.5)
			end
		end)

		Self._watermark = wm
		return wm
	end

	function WindowClass:SetWatermarkVisible(v)
		if Self == nil then
			return
		end
	end

	function WindowClass:WatermarkVisible(v)
		if self._watermark then
			self._watermark.Visible = v and true or false
		end
	end

	----------------------------------------------------------------------
	-- Auto-generated Settings tab
	----------------------------------------------------------------------
	function WindowClass:CreateSettingsTab()
		local tab = self:Tab("Settings", "settings")

		local interface = tab:CreateSection("Interface", { Icon = "palette" })

		interface:Keybind({
			Title = "Menu key",
			Default = self._toggleKey,
			Flag = "__ui_togglekey",
			Tooltip = "Shows / hides the UI",
		})

		-- keep the live toggle key in sync with whatever the bind chip holds
		Shared.Config.Changed:Connect(function(flag, value)
			if flag == "__ui_togglekey" then
				self._toggleKey = Shared.Utility.KeyFromName(value) or self._toggleKey
			end
		end)

		interface:Dropdown({
			Title = "Theme",
			Values = Theme:Names(),
			Default = Theme.Current,
			Flag = "__ui_theme",
			Callback = function(name)
				Theme:Set(name)
			end,
			Tooltip = "Switch color palette",
			Searchable = true,
		})

		interface:Slider({
			Title = "UI scale",
			Min = 0.75, Max = 1.25, Default = 1, Increment = 0.05,
			Flag = "__ui_scale",
			Callback = function(v)
				self._scale.Scale = v
			end,
		})

		interface:Toggle({
			Title = "Acrylic blur",
			Default = self._acrylicAttached,
			Callback = function(v)
				if self._acrylicAttached then
					Shared.Acrylic:SetEnabled(v)
				end
			end,
		})

		interface:Dropdown({
			Title = "Notification position",
			Values = { "TopRight", "TopLeft", "BottomRight", "BottomLeft", "TopCenter", "BottomCenter" },
			Default = "TopRight",
			Callback = function(v)
				Shared.Notify:SetPosition(v)
			end,
		})

		interface:Toggle({
			Title = "Watermark",
			Default = self._watermark ~= nil,
			Callback = function(v)
				if self._watermark then
					self._watermark.Visible = v
				end
			end,
		})

		local configGroup = tab:CreateSection("Configuration", { Icon = "save" })
		if Shared.Addons and Shared.Addons.SaveManager then
			Shared.Addons.SaveManager:SetLibrary(Shared.Library):SetFolder(Config.Folder)
			Shared.Addons.SaveManager:ApplyToTab(configGroup)
		else
			configGroup:Button({ Title = "Save config", Callback = function()
				Config:Save()
				self:Notify({ Title = "Saved", Content = "Config written", Type = "Success", Duration = 2 })
			end })
			configGroup:Button({ Title = "Load config", Callback = function()
				Config:Load()
			end })
		end

		if Shared.Addons and Shared.Addons.ThemeManager then
			local themeGroup = tab:CreateSection("Custom Theme", { Icon = "droplet" })
			Shared.Addons.ThemeManager:SetLibrary(Shared.Library)
			Shared.Addons.ThemeManager:ApplyToTab(themeGroup)
		end

		local danger = tab:CreateSection("Danger Zone", { Icon = "alert-triangle" })
		danger:Button({
			Title = "Unload UI",
			Description = "Destroys the window and releases keybinds",
			Variant = "Danger",
			HoldToConfirm = true,
			Callback = function()
				self:Destroy()
			end,
		})

		danger:Label("Tracium v" .. Shared.Version)

		return tab
	end

	return WindowClass
end

end)()

--===========================[ Addons.ThemeManager ]===========================--
__MODULES["Addons.ThemeManager"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Addons/ThemeManager.lua
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

end)()

--===========================[ Addons.SaveManager ]===========================--
__MODULES["Addons.SaveManager"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Addons/SaveManager.lua
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

end)()

--===========================[ Addons.KeybindList ]===========================--
__MODULES["Addons.KeybindList"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Addons/KeybindList.lua
-- Floating, draggable panel listing every live keybind (mspaint style).
--
--   local list = KeybindList:Show()
--   KeybindList:Hide(); KeybindList:Toggle()
--[[==========================================================================]]

return function(Shared)
	local KL = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	local gui, panel, listScroll
	local visible = false

	local function build()
		gui = Utility.New("ScreenGui", {
			Name = "TraciumKeybindList",
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = 800,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
		Utility.ProtectGui(gui)

		panel = Utility.New("Frame", {
			Name = "Panel",
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 16, 0.35, 0),
			Size = UDim2.new(0, 200, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme:Get("Surface"),
			Visible = false,
			Parent = gui,
		})
		Utility.Paint(panel, "BackgroundColor3", "Surface")
		Utility.Round(panel, 10)
		Utility.Stroke(panel, "Stroke", 1, 0.4)

		local head = Utility.New("Frame", {
			Name = "Head",
			BackgroundColor3 = Theme:Get("Card"),
			Size = UDim2.new(1, 0, 0, 26),
			Parent = panel,
		})
		Utility.Paint(head, "BackgroundColor3", "Card")
		Utility.Round(head, 10)
		local title = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Theme:Get("Text"),
			Text = "Keybinds",
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(1, -40, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = head,
		})
		Utility.Paint(title, "TextColor3", "Text")

		Icons:Create("keyboard", { Size = 13, Color = "Accent", AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0), Parent = head })

		listScroll = Utility.New("ScrollingFrame", {
			Name = "List",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 26),
			Size = UDim2.new(1, 0, 0, 0),
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 2,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = panel,
		})
		Utility.Paint(listScroll, "ScrollBarImageColor3", "Muted")
		Utility.ListLayout(listScroll, { Padding = 0 })
		Utility.Pad(listScroll, 4, 4, 4, 4)

		Shared.Drag:MakeDraggable(head, panel, { Lerp = 0.35 })

		-- keep list fresh
		local refresh = Utility.Debounce(0.12, function()
			if not visible then
				return
			end
			for _, c in ipairs(listScroll:GetChildren()) do
				if c:IsA("Frame") then
					c:Destroy()
				end
			end
			local any = false
			for _, entry in ipairs(Shared.Keybinds or {}) do
				any = true
				local row = Utility.New("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 18),
					Parent = listScroll,
				})
				local name = Utility.New("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					TextSize = 11,
					TextColor3 = Theme:Get("SubText"),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Size = UDim2.new(1, -70, 1, 0),
					Text = entry.Title,
					Parent = row,
				})
				Utility.Paint(name, "TextColor3", "SubText")

				local keyName = "None"
				local kb = entry.Ref
				if kb and kb.Value then
					keyName = Utility.KeyName(kb.Value)
				end

				local chip = Utility.New("TextLabel", {
					BackgroundColor3 = Theme:Get("Input"),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					TextColor3 = Theme:Get("Text"),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 30, 1, -2),
					Text = " " .. keyName .. " ",
					Parent = row,
				})
				Utility.Paint(chip, "BackgroundColor3", "Input")
				Utility.Paint(chip, "TextColor3", "Text")
				Utility.Round(chip, 4)
			end
			if not any then
				local row = Utility.New("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					TextSize = 11,
					TextColor3 = Theme:Get("Muted"),
					Text = "No keybinds",
					Size = UDim2.new(1, 0, 0, 18),
					Parent = listScroll,
				})
				Utility.Paint(row, "TextColor3", "Muted")
			end
		end)
		Shared.RefreshKeybindList = refresh
	end

	function KL:Show()
		if not gui then
			build()
		end
		visible = true
		if panel then
			panel.Visible = true
			panel.GroupTransparency = nil
			Tween:Play(panel, "PanelSlide", { Position = UDim2.new(0, 16, 0.35, 0) })
		end
		if Shared.RefreshKeybindList then
			Shared.RefreshKeybindList()
		end
	end

	function KL:Hide()
		visible = false
		if panel then
			Tween:Play(panel, "Fade", { Position = UDim2.new(0, 16, 0.4, 0) })
			task.delay(0.2, function()
				if panel then
					panel.Visible = false
				end
			end)
		end
	end

	function KL:Toggle()
		if visible then
			KL:Hide()
		else
			KL:Show()
		end
	end

	function KL:IsVisible()
		return visible
	end

	-- refresh when keybinds change
	task.spawn(function()
		while true do
			task.wait(0.5)
			if visible and Shared.RefreshKeybindList then
				Shared.RefreshKeybindList()
			end
		end
	end)

	return KL
end

end)()

--===========================[ Init ]===========================--
__MODULES["Init"] = (function()
--[[==========================================================================]]
-- Tracium v2 Â· Init.lua
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
	Shared.Icons = Shared.Load("Core.Icons")
	Shared.Drag = Shared.Load("Core.Drag")
	Shared.Acrylic = Shared.Load("Core.Acrylic")
	Shared.Tooltip = Shared.Load("Core.Tooltip")
	Shared.Theme = Shared.Load("Core.Theme")
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

end)()

-- bootstrap: constructors map -> Init
return __MODULES["Init"](__MODULES)
]====]

