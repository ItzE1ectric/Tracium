--[[==========================================================================]]
-- Tracium v2 · Core/Tween.lua
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
