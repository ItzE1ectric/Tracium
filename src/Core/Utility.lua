--[[==========================================================================]]
-- Tracium v2 · Core/Utility.lua
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

	-- Run fn no more often than `seconds` — calls collapse (last call wins).
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
