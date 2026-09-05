--[[==========================================================================]]
-- Tracium v2 · test/mock.lua
-- Minimal headless Roblox environment for running Tracium under stock luau.
-- Only implements what the library actually touches. Both mock and library
-- get verbose on divergence instead of crashing silently.
--[[==========================================================================]]

local Mock = {}

local function mkSignal(name)
	local s = { _c = {}, Name = name }
	function s:Connect(fn)
		local c = { Connected = true, _fn = fn }
		function c:Disconnect()
			c.Connected = false
		end
		table.insert(self._c, c)
		return c
	end
	function s:Fire(...)
		for _, c in ipairs(self._c) do
			if c.Connected then
				-- direct call with protection; handlers that yield just die quietly
				local ok, err = pcall(c._fn, ...)
				if not ok and not tostring(err):find("attempt to yield") then
					-- log real errors only
					print("[signal error]", err)
				end
			end
		end
	end
	function s:Wait()
		local th = coroutine.running()
		local conn
		conn = self:Connect(function(...)
			conn:Disconnect()
			task.spawn(th, ...)
		end)
		return coroutine.yield()
	end
	return s
end
Mock.Signal = mkSignal

local function mkInstance(class)
	local inst
	inst = setmetatable({
		ClassName = class,
		_children = {},
		_props = {},
		_signals = {},
	}, {
		__index = function(self, k)
			local props = rawget(self, "_props")
			if props[k] ~= nil then
				return props[k]
			end
			-- auto-signals for input events + common ones
			if k:match("^[A-Z]") and (k:match("Click$") or k:match("Began$") or k:match("Ended$")
				or k:match("Enter$") or k:match("Leave$") or k:match("Focused$") or k:match("FocusLost$")
				or k:match("Forward$") or k:match("Backward$") or k:match("Moved$")
				or k:match("Down$") or k:match("Up$") or k:match("Changed$") or k:match("Activated$")
				or k:match("Removed$") or k:match("Added$") or k:match("Emitted$")) then
				local sigs = rawget(self, "_signals")
				if not sigs[k] then
					sigs[k] = mkSignal(k)
				end
				return sigs[k]
			end
			if k == "Parent" then
				return rawget(self, "_parent")
			end
			-- methods
			if k == "GetChildren" then
				return function()
					local out = {}
					for _, c in ipairs(rawget(self, "_children")) do
						table.insert(out, c)
					end
					return out
				end
			end
			if k == "FindFirstChild" then
				return function(_, name)
					for _, c in ipairs(rawget(self, "_children")) do
						if c.Name == name then
							return c
						end
					end
					return nil
				end
			end
			if k == "Destroy" then
				return function()
					local p = rawget(self, "_parent")
					if p then
						local pcs = rawget(p, "_children")
						for i, c in ipairs(pcs) do
							if c == self then
								table.remove(pcs, i)
								break
							end
						end
						rawset(self, "_parent", nil)
					end
				end
			end
			if k == "GetPropertyChangedSignal" then
				return function(_, prop)
					local sigs = rawget(self, "_signals")
					if not sigs["__prop_" .. prop] then
						sigs["__prop_" .. prop] = mkSignal(prop)
					end
					return sigs["__prop_" .. prop]
				end
			end
			if k == "SetAttribute" then
				return function(_, name, val)
					rawget(self, "_props")["__attr_" .. name] = val
				end
			end
			if k == "GetAttribute" then
				return function(_, name)
					return rawget(self, "_props")["__attr_" .. name]
				end
			end
			if k == "IsA" then
				return function(_, cls)
					return class == cls
				end
			end
			if k == "WaitForChild" then
				return function(_, name)
					return self:FindFirstChild(name) or mkInstance("Folder")
				end
			end
			return nil -- unknown members read as nil (executor-robust)
		end,
		__newindex = function(self, k, v)
			if k == "Parent" then
				local old = rawget(self, "_parent")
				if old then
					local ch = rawget(old, "_children")
					for i, c in ipairs(ch) do
						if c == self then
							table.remove(ch, i)
							break
						end
					end
				end
				rawset(self, "_parent", v)
				if v then
					table.insert(rawget(v, "_children"), self)
				end
				return
			end
			rawget(self, "_props")[k] = v
			local sigs = rawget(self, "_signals")
			if sigs["__prop_" .. k] then
				sigs["__prop_" .. k]:Fire()
			end
			if k == "Text" and sigs.Text then
				sigs.Text:Fire()
			end
		end,
		__tostring = function()
			return "MockInstance(" .. class .. ")"
		end,
	})
	-- sensible defaults (V2 injected by BuildEnv)
	local V2 = Mock._V2 or { new = function(x, y) return { X = x or 0, Y = y or 0 } end }
	inst._props.Name = class
	inst._props.Visible = true
	inst._props.AbsolutePosition = V2.new(0, 0)
	inst._props.AbsoluteSize = V2.new(100, 40)
	inst._props.AbsoluteRotation = 0
	inst._props.AbsoluteContentSize = V2.new(0, 0)
	inst._props.CanvasPosition = V2.new(0, 0)
	return inst
end
Mock.InstanceNew = mkInstance

function Mock.BuildEnv()
	local Vector2 = {}
	Vector2.__index = Vector2
	function Vector2.new(x, y)
		return setmetatable({ X = x or 0, Y = y or 0, __type = "Vector2" }, Vector2)
	end
	Vector2.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
	Vector2.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
	Vector2.__mul = function(a, b)
		if type(a) == "number" then
			return Vector2.new(a * b.X, a * b.Y)
		end
		return Vector2.new(a.X * b, a.Y * b)
	end
	Vector2.__tostring = function(v)
		return ("Vector2(%s, %s)"):format(v.X, v.Y)
	end
	Vector2.zero = Vector2.new(0, 0)
	Mock._V2 = Vector2

	local Color3 = {}
	Color3.__index = Color3
	function Color3.new(r, g, b)
		return setmetatable({ R = r or 0, G = g or 0, B = b or 0, __type = "Color3" }, Color3)
	end
	function Color3.fromRGB(r, g, b)
		return Color3.new(r / 255, g / 255, b / 255)
	end
	function Color3.fromHSV(h, s, v)
		h = h % 1
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p = v * (1 - s)
		local q = v * (1 - f * s)
		local t = v * (1 - (1 - f) * s)
		local r, g, b
		local m = i % 6
		if m == 0 then r, g, b = v, t, p
		elseif m == 1 then r, g, b = q, v, p
		elseif m == 2 then r, g, b = p, v, t
		elseif m == 3 then r, g, b = p, q, v
		elseif m == 4 then r, g, b = t, p, v
		else r, g, b = v, p, q end
		return Color3.new(r, g, b)
	end
	function Color3.toHSV(c)
		local r, g, b = c.R, c.G, c.B
		local max = math.max(r, g, b)
		local min = math.min(r, g, b)
		local d = max - min
		local h = 0
		if d > 1e-6 then
			if max == r then h = ((g - b) / d) % 6
			elseif max == g then h = (b - r) / d + 2
			else h = (r - g) / d + 4 end
			h = h / 6
		end
		local s = max < 1e-6 and 0 or d / max
		return h, s, max
	end

	local UDim2 = {}
	local UDim2_mt = {
		__mul = function(a, b)
			return UDim2.new(a.X.Scale * b, a.X.Offset * b, a.Y.Scale * b, a.Y.Offset * b)
		end,
		__add = function(a, b)
			return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
		end,
	}
	function UDim2.new(xs, xo, ys, yo)
		if type(xs) == "number" and xo == nil then
			xo, ys, yo = 0, 0, 0
		end
		return setmetatable(
			{ X = { Scale = xs or 0, Offset = xo or 0 }, Y = { Scale = ys or 0, Offset = yo or 0 }, __type = "UDim2" },
			UDim2_mt
		)
	end
	function UDim2.fromOffset(x, y) return UDim2.new(0, x or 0, 0, y or 0) end
	function UDim2.fromScale(x, y) return UDim2.new(x or 0, 0, y or 0, 0) end

	local UDim = {}
	function UDim.new(s, o) return { Scale = s or 0, Offset = o or 0, __type = "UDim" } end

	local TweenInfo = {}
	function TweenInfo.new(t, ...)
		return { Time = t or 0.2, __type = "TweenInfo" }
	end

	local ColorSequence
	ColorSequence = {} -- simplified
	function ColorSequence.new(...)
		return { __type = "ColorSequence" }
	end
	local ColorSequenceKeypoint = {}
	function ColorSequenceKeypoint.new(t, c)
		return { Time = t, Value = c }
	end
	local NumberSequence = {}
	function NumberSequence.new(...)
		return { __type = "NumberSequence" }
	end
	local NumberSequenceKeypoint = {}
	function NumberSequenceKeypoint.new(t, v)
		return { Time = t, Value = v }
	end

	local Enum = {}
	local function makeEnumCat(name)
		local cat = {}
		setmetatable(cat, {
			__index = function(_, item)
				local e = { Name = item, Value = 0, EnumType = { Name = name }, __type = "EnumItem" }
				rawset(cat, item, e)
				return e
			end,
		})
		Enum[name] = cat
		return cat
	end
	setmetatable(Enum, {
		__index = function(_, name)
			return makeEnumCat(name)
		end,
	})
	-- text alignments are used a lot
	Enum.TextXAlignment.Left = { Name = "Left" }
	Enum.TextXAlignment.Right = { Name = "Right" }
	Enum.AutomaticSize.Y = { Name = "Y" }
	Enum.AutomaticSize.XY = { Name = "XY" }
	Enum.AutomaticSize.None = { Name = "None" }

	local Instance = { new = mkInstance }

	local tweenService = {}
	function tweenService:Create(inst, info, props)
		local done = mkSignal("Completed")
		return {
			Completed = done,
			PlaybackState = { Name = "Begin" },
			Play = function(self)
				for k, v in pairs(props) do
					inst[k] = v
				end
				done:Fire()
			end,
			Cancel = function() end,
			Pause = function() end,
		}
	end

	local function serviceTable(name)
		local t = { Name = name }
		return t
	end

	local UIS = serviceTable("UserInputService")
	UIS.InputBegan = mkSignal("InputBegan")
	UIS.InputChanged = mkSignal("InputChanged")
	UIS.InputEnded = mkSignal("InputEnded")
	UIS.MouseMovement = { Name = "MouseMovement" }
	function UIS:GetFocusedTextBox()
		return nil
	end
	function UIS:GetMouseLocation()
		return Vector2.new(800, 400)
	end
	function UIS:IsMouseButtonPressed()
		return false
	end

	local runService = mkSignal("RenderStepped")
	local RS = {
		RenderStepped = runService,
		Stepped = mkSignal("Stepped"),
		Heartbeat = mkSignal("Heartbeat"),
	}

	local httpService = {}
	function httpService:JSONEncode(v)
		-- minimal
		if type(v) ~= "table" then
			return tostring(v)
		end
		local parts = {}
		for k, val in pairs(v) do
			table.insert(parts, '"' .. tostring(k) .. '":"x"')
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	function httpService:JSONDecode(s)
		return {}
	end
	local guidCounter = 0
	function httpService:GenerateGUID()
		guidCounter += 1
		return ("00000000-0000-0000-0000-%012d"):format(guidCounter)
	end

	local stats = {
		Network = { ServerStatsItem = { ["Data Ping"] = { GetValue = function() return 42 end } } },
	}

	local textService = {}
	function textService:GetTextSize(text, size, font, maxW)
		return Vector2.new(#tostring(text) * (size or 12) * 0.55, size or 12)
	end

	local players = { LocalPlayer = { Name = "MockPlayer", DisplayName = "Mock Player", UserId = 1,
		WaitForChild = function(_, n) return mkInstance("Folder") end } }
	function players:GetUserThumbnailAsync()
		return "rbxassetid://0", true
	end

	local coreGui = mkInstance("ScreenGui")
	local workspace = { CurrentCamera = { ViewportSize = Vector2.new(1920, 1080) } }

	local game = {}
	local registry = {
		TweenService = tweenService,
		UserInputService = UIS,
		RunService = RS,
		HttpService = httpService,
		Lighting = mkInstance("Folder"),
		Players = players,
		TextService = textService,
		GuiService = mkInstance("Folder"),
		CoreGui = coreGui,
		Workspace = workspace,
		Stats = stats,
	}
	function game:GetService(name)
		return registry[name] or mkInstance("Folder")
	end

	-- cooperative task scheduler (luau standalone has no task lib)
	local queue = {}
	local MockTask = {}
	function MockTask.spawn(fn, ...)
		local co = coroutine.create(fn)
		table.insert(queue, { co = co, args = table.pack(...) })
	end
	MockTask.defer = MockTask.spawn
	function MockTask.delay(_, fn, ...)
		MockTask.spawn(fn, ...)
	end
	function MockTask.wait()
		return coroutine.yield()
	end
	function MockTask.despawn() end

	local function pump(maxSteps)
		local steps = 0
		while #queue > 0 and steps < (maxSteps or 2000) do
			local item = table.remove(queue, 1)
			if coroutine.status(item.co) ~= "dead" then
				local ok, err = coroutine.resume(item.co, table.unpack(item.args))
				if not ok then
					print("[mock][task error]", err)
				end
				steps += 1
			end
		end
		if #queue > 0 then
			print(("[mock] scheduler budget exhausted; %d pending (loops are normal)"):format(#queue))
		end
	end
	MockTask._pump = pump

	local env = {
		Color3 = Color3, Vector2 = Vector2, UDim2 = UDim2, UDim = UDim,
		TweenInfo = TweenInfo, Enum = Enum, Instance = Instance,
		ColorSequence = ColorSequence, ColorSequenceKeypoint = ColorSequenceKeypoint,
		NumberSequence = NumberSequence, NumberSequenceKeypoint = NumberSequenceKeypoint,
		game = game,
		tick = os.clock,
		task = MockTask,
		typeof = function(v)
			if type(v) == "table" and rawget(v, "__type") then
				return v.__type
			end
			if type(v) == "table" and getmetatable(v) and rawget(getmetatable(v), "__tostring") then
				return "Instance"
			end
			return type(v)
		end,
		warn = print,
	}
	return env
end

-- Run a big source string with the mock env; luau standalone: no io lib, so
-- the caller supplies `src` directly.
function Mock.RunSource(env, src, chunkName)
	local chunk, err = loadstring(src, chunkName or "@Tracium")
	if not chunk then
		error("bundle parse failed: " .. tostring(err))
	end
	local Env = setmetatable({}, {
		__index = function(_, k)
			if env[k] ~= nil then
				return env[k]
			end
			return _G[k]
		end,
	})
	setfenv(chunk, Env)
	local ok, result = xpcall(chunk, function(e)
		return tostring(e) .. "\n" .. debug.traceback("", 2)
	end)
	if not ok then
		error("runtime error: " .. tostring(result))
	end
	return result, Env, env
end

return Mock
