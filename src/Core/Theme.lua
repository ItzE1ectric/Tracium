--[[==========================================================================]]
-- Tracium v2 · Core/Theme.lua
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
