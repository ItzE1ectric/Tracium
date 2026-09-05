--[[
	Tracium UI Library  ·  v1.1.0
	Looks: WindUI chrome · Fluent acrylic · Rayfield sidebar · Linoria accent

	local Tracium = loadstring(game:HttpGet("https://raw.githubusercontent.com/ItzE1ectric/Tracium/main/Tracium.lua"))()
	local Window = Tracium:Create({ Title = "My Hub", Tag = "v1" })
	local Main = Window:Tab("Main")
	Main:Toggle("Auto Farm", false, function(on) end)
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local Tracium = {
	Version = "1.1.0",
	Flags = {},
	Windows = {},
}

local FONT_B = Enum.Font.GothamBold
local FONT_M = Enum.Font.GothamMedium
local FONT_R = Enum.Font.Gotham

local Themes = {
	Midnight = {
		Background = Color3.fromRGB(12, 13, 18),
		Surface = Color3.fromRGB(18, 20, 28),
		Sidebar = Color3.fromRGB(15, 16, 23),
		Inset = Color3.fromRGB(14, 15, 21),
		Card = Color3.fromRGB(24, 26, 36),
		CardHover = Color3.fromRGB(30, 33, 46),
		Stroke = Color3.fromRGB(52, 58, 78),
		Text = Color3.fromRGB(244, 246, 252),
		SubText = Color3.fromRGB(148, 156, 178),
		Muted = Color3.fromRGB(92, 100, 122),
		Accent = Color3.fromRGB(99, 162, 255),
		Accent2 = Color3.fromRGB(168, 132, 255),
		Success = Color3.fromRGB(80, 222, 168),
		Danger = Color3.fromRGB(255, 92, 118),
		Warn = Color3.fromRGB(255, 196, 92),
		Shadow = Color3.fromRGB(0, 0, 0),
		Glow = Color3.fromRGB(99, 162, 255),
	},
	Aurora = {
		Background = Color3.fromRGB(8, 16, 18),
		Surface = Color3.fromRGB(12, 24, 28),
		Sidebar = Color3.fromRGB(9, 18, 22),
		Inset = Color3.fromRGB(8, 18, 22),
		Card = Color3.fromRGB(16, 34, 38),
		CardHover = Color3.fromRGB(22, 46, 52),
		Stroke = Color3.fromRGB(40, 78, 84),
		Text = Color3.fromRGB(236, 252, 248),
		SubText = Color3.fromRGB(140, 176, 178),
		Muted = Color3.fromRGB(82, 114, 118),
		Accent = Color3.fromRGB(56, 224, 196),
		Accent2 = Color3.fromRGB(92, 168, 255),
		Success = Color3.fromRGB(80, 222, 168),
		Danger = Color3.fromRGB(255, 92, 118),
		Warn = Color3.fromRGB(255, 196, 92),
		Shadow = Color3.fromRGB(0, 0, 0),
		Glow = Color3.fromRGB(56, 224, 196),
	},
	Ember = {
		Background = Color3.fromRGB(16, 11, 10),
		Surface = Color3.fromRGB(24, 16, 14),
		Sidebar = Color3.fromRGB(20, 13, 12),
		Inset = Color3.fromRGB(18, 12, 11),
		Card = Color3.fromRGB(34, 22, 20),
		CardHover = Color3.fromRGB(46, 28, 24),
		Stroke = Color3.fromRGB(82, 50, 42),
		Text = Color3.fromRGB(255, 244, 236),
		SubText = Color3.fromRGB(184, 152, 140),
		Muted = Color3.fromRGB(122, 94, 84),
		Accent = Color3.fromRGB(255, 138, 72),
		Accent2 = Color3.fromRGB(255, 198, 92),
		Success = Color3.fromRGB(80, 222, 168),
		Danger = Color3.fromRGB(255, 92, 118),
		Warn = Color3.fromRGB(255, 196, 92),
		Shadow = Color3.fromRGB(0, 0, 0),
		Glow = Color3.fromRGB(255, 138, 72),
	},
	Violet = {
		Background = Color3.fromRGB(14, 11, 22),
		Surface = Color3.fromRGB(22, 16, 34),
		Sidebar = Color3.fromRGB(18, 13, 28),
		Inset = Color3.fromRGB(16, 12, 26),
		Card = Color3.fromRGB(30, 22, 46),
		CardHover = Color3.fromRGB(40, 30, 60),
		Stroke = Color3.fromRGB(72, 56, 108),
		Text = Color3.fromRGB(246, 240, 255),
		SubText = Color3.fromRGB(168, 154, 198),
		Muted = Color3.fromRGB(110, 98, 148),
		Accent = Color3.fromRGB(186, 132, 255),
		Accent2 = Color3.fromRGB(255, 122, 196),
		Success = Color3.fromRGB(80, 222, 168),
		Danger = Color3.fromRGB(255, 92, 118),
		Warn = Color3.fromRGB(255, 196, 92),
		Shadow = Color3.fromRGB(0, 0, 0),
		Glow = Color3.fromRGB(186, 132, 255),
	},
	Snow = {
		Background = Color3.fromRGB(236, 240, 248),
		Surface = Color3.fromRGB(255, 255, 255),
		Sidebar = Color3.fromRGB(226, 232, 244),
		Inset = Color3.fromRGB(242, 246, 252),
		Card = Color3.fromRGB(248, 250, 255),
		CardHover = Color3.fromRGB(232, 238, 250),
		Stroke = Color3.fromRGB(196, 206, 224),
		Text = Color3.fromRGB(20, 26, 40),
		SubText = Color3.fromRGB(88, 98, 120),
		Muted = Color3.fromRGB(128, 138, 158),
		Accent = Color3.fromRGB(68, 122, 255),
		Accent2 = Color3.fromRGB(132, 96, 255),
		Success = Color3.fromRGB(28, 168, 122),
		Danger = Color3.fromRGB(220, 64, 90),
		Warn = Color3.fromRGB(210, 140, 40),
		Shadow = Color3.fromRGB(40, 50, 70),
		Glow = Color3.fromRGB(68, 122, 255),
	},
}

local function CloneRef(obj)
	local ok, cloned = pcall(function()
		return cloneref(obj)
	end)
	return (ok and cloned) or obj
end

TweenService = CloneRef(TweenService)
UserInputService = CloneRef(UserInputService)
HttpService = CloneRef(HttpService)
RunService = CloneRef(RunService)
Lighting = CloneRef(Lighting)
Players = CloneRef(Players)
CoreGui = CloneRef(CoreGui)

local function ProtectGui(gui)
	pcall(function()
		gui.OnTopOfCoreBlur = true
	end)
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, gui)
	end
	if gethui then
		local ok, parent = pcall(gethui)
		if ok and parent then
			gui.Parent = parent
			return
		end
	end
	if not pcall(function()
		gui.Parent = CoreGui
	end) then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end

local function Tween(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

local T_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local T_MED = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local T_SPRING = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local T_SOFT = TweenInfo.new(0.32, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

local function New(class, props)
	local inst = Instance.new(class)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then
				inst[k] = v
			end
		end
		if props.Parent then
			inst.Parent = props.Parent
		end
	end
	return inst
end

local function Corner(parent, radius)
	return New("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

local function Stroke(parent, color, thickness, trans)
	return New("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = trans or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function Pad(parent, l, t, r, b)
	if typeof(l) == "number" and t == nil then
		t, r, b = l, l, l
	end
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0),
		PaddingBottom = UDim.new(0, b or 0),
		Parent = parent,
	})
end

local function Gradient(parent, c1, c2, rotation)
	return New("UIGradient", {
		Color = ColorSequence.new(c1, c2),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

local function ClearGradients(inst)
	for _, c in ipairs(inst:GetChildren()) do
		if c:IsA("UIGradient") then
			c:Destroy()
		end
	end
end

local function TableOpts(first, defaults)
	local o = {}
	for k, v in pairs(defaults or {}) do
		o[k] = v
	end
	if type(first) == "table" then
		for k, v in pairs(first) do
			o[k] = v
		end
	end
	return o
end

local function EncodeFlag(value)
	if typeof(value) == "Color3" then
		return { t = "Color3", r = value.R, g = value.G, b = value.B }
	end
	if typeof(value) == "EnumItem" then
		return { t = "Enum", enum = tostring(value.EnumType), name = value.Name }
	end
	return value
end

local function DecodeFlag(value)
	if type(value) == "table" and value.t == "Color3" then
		return Color3.new(value.r, value.g, value.b)
	end
	if type(value) == "table" and value.t == "Enum" then
		local ok, enumType = pcall(function()
			return Enum[value.enum]
		end)
		if ok and enumType then
			return enumType[value.name]
		end
	end
	return value
end

local function SafeWrite(path, contents)
	if writefile then
		pcall(writefile, path, contents)
	end
end

local function SafeRead(path)
	if readfile and isfile and isfile(path) then
		local ok, data = pcall(readfile, path)
		if ok then
			return data
		end
	end
	return nil
end

local function MakeDraggable(handle, target, extra)
	local dragging, startPos, startInput, extraStart
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			startPos = target.Position
			extraStart = extra and extra.Position
			startInput = input.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - startInput
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			if extra and extraStart then
				extra.Position = UDim2.new(extraStart.X.Scale, extraStart.X.Offset + delta.X, extraStart.Y.Scale, extraStart.Y.Offset + delta.Y)
			end
		end
	end)
end

local function ConnectCanvas(scroll, layout)
	local function update()
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 22)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
	update()
end

local function HoverFill(btn, rest, hover)
	btn.MouseEnter:Connect(function()
		Tween(btn, T_FAST, { BackgroundColor3 = hover })
	end)
	btn.MouseLeave:Connect(function()
		Tween(btn, T_FAST, { BackgroundColor3 = rest })
	end)
end

function Tracium:Notify(opts)
	if type(opts) == "string" then
		opts = { Title = "Tracium", Content = opts, Duration = 4 }
	end
	opts = TableOpts(opts, { Title = "Tracium", Content = "", Duration = 4 })
	local gui = self._notifyGui
	if not gui or not gui.Parent then
		gui = New("ScreenGui", {
			Name = "TraciumNotify",
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			IgnoreGuiInset = true,
			DisplayOrder = 1200,
		})
		ProtectGui(gui)
		self._notifyGui = gui
		New("Frame", {
			Name = "Stack",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -20, 0, 20),
			Size = UDim2.new(0, 340, 1, -40),
			Parent = gui,
		})
		New("UIListLayout", {
			Parent = gui.Stack,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		})
	end

	local theme = self._lastTheme or Themes.Midnight
	local card = New("Frame", {
		BackgroundColor3 = theme.Surface,
		Size = UDim2.new(1, 40, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.04,
		Parent = gui.Stack,
	})
	Corner(card, 16)
	local st = Stroke(card, theme.Stroke, 1, 0.25)
	Pad(card, 14, 14, 14, 16)

	local glow = New("Frame", {
		BackgroundColor3 = theme.Accent,
		BackgroundTransparency = 0.82,
		Position = UDim2.new(0, -6, 0, -6),
		Size = UDim2.new(1, 12, 1, 12),
		ZIndex = 0,
		Parent = card,
	})
	Corner(glow, 18)

	local icon = New("Frame", {
		BackgroundColor3 = theme.Accent,
		Size = UDim2.fromOffset(32, 32),
		Parent = card,
	})
	Corner(icon, 10)
	Gradient(icon, theme.Accent, theme.Accent2, 135)
	New("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT_B,
		Text = "T",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
		Size = UDim2.fromScale(1, 1),
		Parent = icon,
	})

	local texts = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 42, 0, 0),
		Size = UDim2.new(1, -42, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = card,
	})
	New("UIListLayout", { Parent = texts, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
	New("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT_B,
		Text = opts.Title,
		TextColor3 = theme.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = texts,
	})
	New("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT_R,
		Text = opts.Content,
		TextColor3 = theme.SubText,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = texts,
	})

	local progress = New("Frame", {
		BackgroundColor3 = theme.Stroke,
		Position = UDim2.new(0, 14, 1, -6),
		Size = UDim2.new(1, -28, 0, 3),
		Parent = card,
		ZIndex = 3,
	})
	Corner(progress, 2)
	local fill = New("Frame", {
		BackgroundColor3 = theme.Accent,
		Size = UDim2.fromScale(1, 1),
		Parent = progress,
	})
	Corner(fill, 2)
	Gradient(fill, theme.Accent, theme.Accent2, 0)

	card.Position = UDim2.new(0, 24, 0, 0)
	Tween(card, T_MED, { Position = UDim2.new(0, 0, 0, 0) })

	if opts.Duration and opts.Duration > 0 then
		Tween(fill, TweenInfo.new(opts.Duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
		task.delay(opts.Duration, function()
			if card.Parent then
				Tween(card, T_MED, { BackgroundTransparency = 1 })
				Tween(st, T_MED, { Transparency = 1 })
				task.wait(0.22)
				card:Destroy()
			end
		end)
	end
	return card
end

function Tracium:Create(opts)
	if type(opts) == "string" then
		opts = { Title = opts }
	end
	opts = TableOpts(opts, {
		Title = "Tracium",
		Subtitle = "UI Library",
		Author = nil,
		Tag = nil,
		Theme = "Midnight",
		Size = UDim2.fromOffset(680, 520),
		ToggleKey = Enum.KeyCode.RightShift,
		Config = nil,
		Acrylic = true,
	})

	local themeName = Themes[opts.Theme] and opts.Theme or "Midnight"
	local theme = {}
	for k, v in pairs(Themes[themeName]) do
		theme[k] = v
	end
	self._lastTheme = theme

	local painted = {}
	local function Paint(inst, prop, key)
		table.insert(painted, { inst = inst, prop = prop, key = key })
		inst[prop] = theme[key]
	end

	local flags = {}
	local setters = {}
	local connections = {}
	local function Bind(signal, fn)
		local c = signal:Connect(fn)
		table.insert(connections, c)
		return c
	end

	local blur
	if opts.Acrylic then
		pcall(function()
			blur = New("BlurEffect", { Name = "TraciumAcrylic", Size = 0, Parent = Lighting })
			Tween(blur, T_SOFT, { Size = 16 })
		end)
	end

	local gui = New("ScreenGui", {
		Name = "Tracium_" .. HttpService:GenerateGUID(false):sub(1, 8),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 999,
	})
	ProtectGui(gui)

	local overlay = New("Frame", {
		Name = "Overlay",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})

	local function LayerShadow(sizeAdd, trans)
		local s = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = opts.Size + UDim2.fromOffset(sizeAdd, sizeAdd),
			BackgroundColor3 = theme.Shadow,
			BackgroundTransparency = trans,
			Parent = overlay,
		})
		Corner(s, 26)
		Paint(s, "BackgroundColor3", "Shadow")
		return s
	end
	local shadowFar = LayerShadow(56, 0.78)
	local shadowMid = LayerShadow(32, 0.68)
	local shadowNear = LayerShadow(16, 0.55)

	local window = New("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = opts.Size,
		BackgroundColor3 = theme.Background,
		BackgroundTransparency = opts.Acrylic and 0.08 or 0,
		ClipsDescendants = true,
		Parent = overlay,
	})
	Corner(window, 20)
	Paint(window, "BackgroundColor3", "Background")
	local winStroke = Stroke(window, theme.Stroke, 1, 0.18)
	Paint(winStroke, "Color", "Stroke")
	local winScale = New("UIScale", { Scale = 0.92, Parent = window })
	Tween(winScale, T_SPRING, { Scale = 1 })

	local sheen = New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 90),
		ZIndex = 2,
		Parent = window,
	})
	New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.88),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 90,
		Parent = sheen,
	})

	local TOP_H = 54
	local top = New("Frame", {
		Name = "Top",
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = 0.12,
		Size = UDim2.new(1, 0, 0, TOP_H),
		ZIndex = 4,
		Parent = window,
	})
	Paint(top, "BackgroundColor3", "Surface")

	local accentLine = New("Frame", {
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 5,
		Parent = top,
	})
	Gradient(accentLine, theme.Accent, theme.Accent2, 0)

	local function Traffic(x, color, symbol, onClick)
		local wrap = New("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, x, 0.5, -8),
			Size = UDim2.fromOffset(16, 16),
			Text = "",
			ZIndex = 6,
			Parent = top,
		})
		local dot = New("Frame", {
			BackgroundColor3 = color,
			Size = UDim2.fromScale(1, 1),
			Parent = wrap,
		})
		Corner(dot, 8)
		local lab = New("TextLabel", {
			BackgroundTransparency = 1,
			Font = FONT_B,
			Text = symbol,
			TextColor3 = Color3.fromRGB(40, 20, 20),
			TextSize = 10,
			TextTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 7,
			Parent = wrap,
		})
		wrap.MouseEnter:Connect(function()
			Tween(lab, T_FAST, { TextTransparency = 0.15 })
			Tween(dot, T_FAST, { Size = UDim2.fromScale(1.08, 1.08) })
		end)
		wrap.MouseLeave:Connect(function()
			Tween(lab, T_FAST, { TextTransparency = 1 })
		end)
		wrap.MouseButton1Click:Connect(onClick)
		return wrap
	end

	local logo = New("Frame", {
		BackgroundColor3 = theme.Accent,
		Position = UDim2.new(0, 78, 0.5, -15),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 6,
		Parent = top,
	})
	Corner(logo, 9)
	Gradient(logo, theme.Accent, theme.Accent2, 135)
	local logoGlow = Stroke(logo, theme.Accent, 4, 0.72)
	New("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT_B,
		Text = "T",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 15,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Parent = logo,
	})

	local titleLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT_B,
		Text = opts.Title,
		TextColor3 = theme.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 118, 0, 9),
		Size = UDim2.new(1, -220, 0, 20),
		ZIndex = 6,
		Parent = top,
	})
	Paint(titleLabel, "TextColor3", "Text")

	local subLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT_R,
		Text = opts.Author or opts.Subtitle,
		TextColor3 = theme.SubText,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 118, 0, 28),
		Size = UDim2.new(1, -220, 0, 16),
		ZIndex = 6,
		Parent = top,
	})
	Paint(subLabel, "TextColor3", "SubText")

	local tagChip = New("TextLabel", {
		BackgroundColor3 = theme.Card,
		Font = FONT_B,
		Text = "  " .. (opts.Tag or ("v" .. Tracium.Version)) .. "  ",
		TextColor3 = theme.Accent,
		TextSize = 11,
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(0, 22),
		ZIndex = 6,
		Parent = top,
	})
	Corner(tagChip, 8)
	local tagStroke = Stroke(tagChip, theme.Accent, 1, 0.55)
	Paint(tagChip, "BackgroundColor3", "Card")
	Paint(tagChip, "TextColor3", "Accent")

	local WindowApi = { Flags = flags, Theme = themeName, Gui = gui }

	local function DestroyAll()
		for _, c in ipairs(connections) do
			c:Disconnect()
		end
		if blur then
			blur:Destroy()
		end
		if gui then
			gui:Destroy()
		end
		if Tracium._notifyGui then
			Tracium._notifyGui:Destroy()
			Tracium._notifyGui = nil
		end
	end

	local closeBtn = Traffic(18, Color3.fromRGB(255, 96, 92), "×", function()
		DestroyAll()
	end)
	local minBtn

	local body = New("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, TOP_H),
		Size = UDim2.new(1, 0, 1, -TOP_H),
		Parent = window,
	})

	local SIDE_W = 178
	local sidebar = New("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = theme.Sidebar,
		BackgroundTransparency = 0.06,
		Size = UDim2.new(0, SIDE_W, 1, 0),
		Parent = body,
	})
	Paint(sidebar, "BackgroundColor3", "Sidebar")

	local sideLine = New("Frame", {
		BackgroundColor3 = theme.Stroke,
		BackgroundTransparency = 0.45,
		Position = UDim2.new(1, -1, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		Parent = sidebar,
	})
	Paint(sideLine, "BackgroundColor3", "Stroke")

	local searchBox = New("TextBox", {
		BackgroundColor3 = theme.Card,
		Font = FONT_R,
		PlaceholderText = "Search",
		PlaceholderColor3 = theme.Muted,
		Text = "",
		TextColor3 = theme.Text,
		TextSize = 13,
		ClearTextOnFocus = false,
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.new(1, -24, 0, 32),
		Parent = sidebar,
	})
	Corner(searchBox, 10)
	local searchStroke = Stroke(searchBox, theme.Stroke, 1, 0.4)
	Pad(searchBox, 10, 0, 10, 0)
	Paint(searchBox, "BackgroundColor3", "Card")
	Paint(searchBox, "TextColor3", "Text")

	local tabList = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, 52),
		Size = UDim2.new(1, -20, 1, -88),
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = theme.Muted,
		CanvasSize = UDim2.new(),
		Parent = sidebar,
	})
	local tabLayout = New("UIListLayout", {
		Parent = tabList,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	ConnectCanvas(tabList, tabLayout)

	local brand = New("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT_M,
		Text = "TRACIUM  ·  " .. Tracium.Version,
		TextColor3 = theme.Muted,
		TextSize = 10,
		Position = UDim2.new(0, 14, 1, -28),
		Size = UDim2.new(1, -28, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sidebar,
	})
	Paint(brand, "TextColor3", "Muted")

	local contentHost = New("Frame", {
		Name = "Content",
		BackgroundColor3 = theme.Inset,
		BackgroundTransparency = 0.35,
		Position = UDim2.new(0, SIDE_W, 0, 0),
		Size = UDim2.new(1, -SIDE_W, 1, 0),
		Parent = body,
	})
	Paint(contentHost, "BackgroundColor3", "Inset")

	local pages, tabButtons, tabOrder = {}, {}, {}
	local selectedTab
	local searchQuery = ""

	local function ApplySearch()
		local q = string.lower(searchQuery)
		if not selectedTab or not pages[selectedTab] then
			return
		end
		for _, child in ipairs(pages[selectedTab]:GetChildren()) do
			if child:IsA("GuiObject") then
				local key = child:GetAttribute("Search")
				if key then
					child.Visible = q == "" or string.find(string.lower(key), q, 1, true) ~= nil
				end
			end
		end
	end
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchQuery = searchBox.Text
		ApplySearch()
	end)

	local function SelectTab(name)
		for n, page in pairs(pages) do
			page.Visible = n == name
			if n == name then
				page.Position = UDim2.new(0, 0, 0, 8)
				Tween(page, T_MED, { Position = UDim2.new() })
			end
		end
		for n, btn in pairs(tabButtons) do
			local active = n == name
			Tween(btn, T_FAST, { BackgroundColor3 = active and theme.Card or theme.Sidebar })
			local marker = btn:FindFirstChild("Marker")
			if marker then
				Tween(marker, T_FAST, { BackgroundTransparency = active and 0 or 1 })
			end
			local ic = btn:FindFirstChild("IconWell")
			if ic then
				Tween(ic, T_FAST, { BackgroundColor3 = active and theme.Accent or theme.Card })
			end
			local label = btn:FindFirstChild("Label")
			if label then
				label.TextColor3 = active and theme.Text or theme.SubText
			end
		end
		selectedTab = name
		ApplySearch()
	end

	local function SyncShadows()
		for _, s in ipairs({ shadowFar, shadowMid, shadowNear }) do
			s.Position = window.Position + UDim2.fromOffset(0, 8)
		end
	end
	window:GetPropertyChangedSignal("Position"):Connect(SyncShadows)
	MakeDraggable(top, window)
	Bind(top.InputBegan, function() end)

	local pill = New("TextButton", {
		Name = "Restore",
		AutoButtonColor = false,
		Visible = false,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -18),
		Size = UDim2.fromOffset(168, 44),
		BackgroundColor3 = theme.Surface,
		Font = FONT_B,
		Text = "   Tracium",
		TextColor3 = theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 14,
		Parent = overlay,
	})
	Corner(pill, 14)
	local pillStroke = Stroke(pill, theme.Accent, 1.5, 0.25)
	Paint(pill, "BackgroundColor3", "Surface")
	Paint(pill, "TextColor3", "Text")
	local pillDot = New("Frame", {
		BackgroundColor3 = theme.Accent,
		Position = UDim2.new(0, 12, 0.5, -8),
		Size = UDim2.fromOffset(16, 16),
		Parent = pill,
	})
	Corner(pillDot, 8)
	Gradient(pillDot, theme.Accent, theme.Accent2, 135)
	MakeDraggable(pill, pill)

	local function SetOpen(open)
		window.Visible = open
		shadowFar.Visible = open
		shadowMid.Visible = open
		shadowNear.Visible = open
		pill.Visible = not open
		if blur then
			Tween(blur, T_SOFT, { Size = open and 16 or 0 })
		end
		if open then
			winScale.Scale = 0.96
			Tween(winScale, T_SPRING, { Scale = 1 })
		end
	end

	minBtn = Traffic(38, Color3.fromRGB(255, 188, 66), "–", function()
		SetOpen(false)
	end)
	Traffic(58, Color3.fromRGB(40, 200, 110), "+", function()
		-- visual only: focus
		Tween(winScale, T_FAST, { Scale = 1.01 })
		task.delay(0.12, function()
			Tween(winScale, T_MED, { Scale = 1 })
		end)
	end)

	function WindowApi:SelectTab(name)
		if pages[name] then
			SelectTab(name)
		elseif type(name) == "number" and tabOrder[name] then
			SelectTab(tabOrder[name])
		end
	end

	local function RecolorChrome()
		ClearGradients(accentLine)
		Gradient(accentLine, theme.Accent, theme.Accent2, 0)
		ClearGradients(logo)
		Gradient(logo, theme.Accent, theme.Accent2, 135)
		logoGlow.Color = theme.Accent
		ClearGradients(pillDot)
		Gradient(pillDot, theme.Accent, theme.Accent2, 135)
		tagStroke.Color = theme.Accent
		pillStroke.Color = theme.Accent
		if selectedTab then
			SelectTab(selectedTab)
		end
	end

	function WindowApi:SetTheme(name)
		if not Themes[name] then
			return
		end
		themeName = name
		for k, v in pairs(Themes[name]) do
			theme[k] = v
		end
		self._lastTheme = theme
		self.Theme = name
		for _, rec in ipairs(painted) do
			if rec.inst and rec.inst.Parent then
				rec.inst[rec.prop] = theme[rec.key]
			end
		end
		RecolorChrome()
	end

	function WindowApi:SetTitle(text)
		titleLabel.Text = text
	end
	function WindowApi:SetSubtitle(text)
		subLabel.Text = text
	end
	function WindowApi:Tag(info)
		if type(info) == "table" then
			tagChip.Text = "  " .. (info.Title or info.Name or "tag") .. "  "
			if info.Color then
				tagChip.TextColor3 = info.Color
				tagStroke.Color = info.Color
			end
		else
			tagChip.Text = "  " .. tostring(info) .. "  "
		end
	end
	function WindowApi:Toggle()
		SetOpen(not window.Visible)
	end
	function WindowApi:Notify(nopts)
		return Tracium:Notify(nopts)
	end

	function WindowApi:Dialog(dopts)
		dopts = TableOpts(dopts, { Title = "Confirm", Content = "", Buttons = {} })
		local dim = New("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 40,
			Parent = window,
		})
		Tween(dim, T_MED, { BackgroundTransparency = 0.4 })
		local box = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(340, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = theme.Surface,
			ZIndex = 41,
			Parent = dim,
		})
		Corner(box, 18)
		Stroke(box, theme.Stroke, 1, 0.2)
		Pad(box, 20, 18, 20, 18)
		local sc = New("UIScale", { Scale = 0.92, Parent = box })
		Tween(sc, T_SPRING, { Scale = 1 })
		New("TextLabel", {
			BackgroundTransparency = 1,
			Font = FONT_B,
			Text = dopts.Title,
			TextColor3 = theme.Text,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 24),
			ZIndex = 42,
			Parent = box,
		})
		New("TextLabel", {
			BackgroundTransparency = 1,
			Font = FONT_R,
			Text = dopts.Content,
			TextColor3 = theme.SubText,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 42,
			Parent = box,
		})
		local row = New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 38),
			ZIndex = 42,
			Parent = box,
		})
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
			Parent = row,
		})
		if not dopts.Buttons or #dopts.Buttons == 0 then
			dopts.Buttons = { { Title = "OK", Callback = function() end } }
		end
		for i, spec in ipairs(dopts.Buttons) do
			local primary = i == #dopts.Buttons
			local b = New("TextButton", {
				AutoButtonColor = false,
				BackgroundColor3 = primary and theme.Accent or theme.Card,
				Font = FONT_B,
				Text = spec.Title or "OK",
				TextColor3 = primary and Color3.new(1, 1, 1) or theme.Text,
				TextSize = 13,
				Size = UDim2.fromOffset(96, 34),
				ZIndex = 43,
				Parent = row,
			})
			Corner(b, 10)
			if primary then
				Gradient(b, theme.Accent, theme.Accent2, 20)
			end
			b.MouseButton1Click:Connect(function()
				dim:Destroy()
				if spec.Callback then
					spec.Callback()
				end
			end)
		end
		return dim
	end

	local function SaveConfig()
		if not opts.Config or not writefile then
			return
		end
		local payload = {}
		for k, v in pairs(flags) do
			payload[k] = EncodeFlag(v)
		end
		local ok, encoded = pcall(HttpService.JSONEncode, HttpService, payload)
		if ok then
			SafeWrite(opts.Config .. ".json", encoded)
		end
	end

	local function LoadConfig()
		if not opts.Config then
			return
		end
		local raw = SafeRead(opts.Config .. ".json")
		if not raw then
			return
		end
		local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok or type(data) ~= "table" then
			return
		end
		for k, v in pairs(data) do
			local decoded = DecodeFlag(v)
			flags[k] = decoded
			Tracium.Flags[k] = decoded
			if setters[k] then
				pcall(setters[k], decoded, true)
			end
		end
	end

	function WindowApi:Save()
		SaveConfig()
	end
	function WindowApi:Load()
		LoadConfig()
	end
	function WindowApi:Destroy()
		DestroyAll()
	end

	local function SetFlag(flag, value)
		if flag then
			flags[flag] = value
			Tracium.Flags[flag] = value
			if opts.Config then
				SaveConfig()
			end
		end
	end

	local function MakePage(name)
		local page = New("ScrollingFrame", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = theme.Muted,
			CanvasSize = UDim2.new(),
			Visible = false,
			Parent = contentHost,
		})
		Pad(page, 16, 16, 16, 16)
		local layout = New("UIListLayout", {
			Parent = page,
			Padding = UDim.new(0, 9),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		ConnectCanvas(page, layout)
		return page
	end

	local function Card(parent, height, search)
		local f = New("Frame", {
			BackgroundColor3 = theme.Card,
			Size = UDim2.new(1, 0, 0, height or 56),
			Parent = parent,
		})
		Corner(f, 14)
		local st = Stroke(f, theme.Stroke, 1, 0.42)
		Paint(f, "BackgroundColor3", "Card")
		Paint(st, "Color", "Stroke")
		f:SetAttribute("Search", search or "")
		f.MouseEnter:Connect(function()
			Tween(f, T_FAST, { BackgroundColor3 = theme.CardHover })
			Tween(st, T_FAST, { Transparency = 0.15, Color = theme.Accent })
		end)
		f.MouseLeave:Connect(function()
			Tween(f, T_FAST, { BackgroundColor3 = theme.Card })
			Tween(st, T_FAST, { Transparency = 0.42, Color = theme.Stroke })
		end)
		return f
	end

	local function TitleBlock(parent, title, desc)
		local wrap = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 16, 0, 0),
			Size = UDim2.new(0.58, 0, 1, 0),
			Parent = parent,
		})
		local t = New("TextLabel", {
			BackgroundTransparency = 1,
			Font = FONT_M,
			Text = title or "",
			TextColor3 = theme.Text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, 0, 0, desc and 10 or 0),
			Size = UDim2.new(1, 0, desc and 0 or 1, desc and 18 or 0),
			Parent = wrap,
		})
		if not desc then
			t.Size = UDim2.new(1, 0, 1, 0)
		end
		Paint(t, "TextColor3", "Text")
		if desc and desc ~= "" then
			local d = New("TextLabel", {
				BackgroundTransparency = 1,
				Font = FONT_R,
				Text = desc,
				TextColor3 = theme.SubText,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.new(0, 0, 0, 28),
				Size = UDim2.new(1, 0, 0, 16),
				Parent = wrap,
			})
			Paint(d, "TextColor3", "SubText")
		end
		return wrap
	end

	local function TabApi(page)
		local api = {}

		function api:Section(title)
			local o = type(title) == "table" and title or { Title = title }
			local row = New("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 26),
				Parent = page,
			})
			row:SetAttribute("Search", o.Title or "")
			local pip = New("Frame", {
				BackgroundColor3 = theme.Accent,
				Position = UDim2.new(0, 2, 0.5, -7),
				Size = UDim2.fromOffset(4, 14),
				Parent = row,
			})
			Corner(pip, 2)
			Gradient(pip, theme.Accent, theme.Accent2, 180)
			local lab = New("TextLabel", {
				BackgroundTransparency = 1,
				Font = FONT_B,
				Text = string.upper(o.Title or "Section"),
				TextColor3 = theme.SubText,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.new(0, 14, 0, 0),
				Size = UDim2.new(1, -14, 1, 0),
				Parent = row,
			})
			Paint(lab, "TextColor3", "SubText")
			return row
		end

		function api:Divider()
			local row = New("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 12),
				Parent = page,
			})
			local line = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = theme.Stroke,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -4, 0, 1),
				Parent = row,
			})
			Paint(line, "BackgroundColor3", "Stroke")
			return row
		end

		function api:Label(text)
			local o = type(text) == "table" and text or { Title = text }
			local card = Card(page, 40, o.Title)
			local lab = New("TextLabel", {
				BackgroundTransparency = 1,
				Font = FONT_R,
				Text = o.Title or o.Text or "",
				TextColor3 = theme.SubText,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.new(0, 16, 0, 0),
				Size = UDim2.new(1, -32, 1, 0),
				Parent = card,
			})
			Paint(lab, "TextColor3", "SubText")
			return {
				Set = function(_, v)
					lab.Text = tostring(v)
				end,
			}
		end

		function api:Paragraph(title, content)
			local o = type(title) == "table" and title or { Title = title, Content = content }
			local card = Card(page, 0, o.Title)
			card.AutomaticSize = Enum.AutomaticSize.Y
			Pad(card, 16, 14, 16, 14)
			local t = New("TextLabel", {
				BackgroundTransparency = 1,
				Font = FONT_B,
				Text = o.Title or "Info",
				TextColor3 = theme.Text,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 18),
				Parent = card,
			})
			Paint(t, "TextColor3", "Text")
			local c = New("TextLabel", {
				BackgroundTransparency = 1,
				Font = FONT_R,
				Text = o.Content or "",
				TextColor3 = theme.SubText,
				TextSize = 13,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = card,
			})
			Paint(c, "TextColor3", "SubText")
			return {
				SetTitle = function(_, v)
					t.Text = v
				end,
				SetContent = function(_, v)
					c.Text = v
				end,
			}
		end

		function api:Button(a, b)
			local o = type(a) == "table" and TableOpts(a, { Title = "Button" }) or { Title = a, Callback = b }
			local card = Card(page, o.Description and 62 or 54, o.Title)
			TitleBlock(card, o.Title, o.Description)
			local btn = New("TextButton", {
				AutoButtonColor = false,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(92, 32),
				BackgroundColor3 = theme.Accent,
				Font = FONT_B,
				Text = o.Text or "Run",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 13,
				Parent = card,
			})
			Corner(btn, 9)
			Gradient(btn, theme.Accent, theme.Accent2, 18)
			btn.MouseButton1Click:Connect(function()
				Tween(btn, T_FAST, { BackgroundTransparency = 0.28 })
				task.delay(0.12, function()
					Tween(btn, T_FAST, { BackgroundTransparency = 0 })
				end)
				if o.Callback then
					o.Callback()
				end
			end)
			return btn
		end

		function api:Toggle(a, b, c)
			local o
			if type(a) == "table" then
				o = TableOpts(a, { Title = "Toggle", Default = false })
			else
				o = {
					Title = a,
					Default = type(b) == "boolean" and b or false,
					Callback = type(b) == "function" and b or c,
				}
			end
			local state = o.Default and true or false
			if o.Flag and flags[o.Flag] ~= nil then
				state = flags[o.Flag] and true or false
			end
			local card = Card(page, o.Description and 62 or 54, o.Title)
			TitleBlock(card, o.Title, o.Description)
			local track = New("TextButton", {
				AutoButtonColor = false,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -16, 0.5, 0),
				Size = UDim2.fromOffset(46, 26),
				BackgroundColor3 = state and theme.Accent or theme.Stroke,
				Text = "",
				Parent = card,
			})
			Corner(track, 13)
			local glow = Stroke(track, theme.Accent, 0, 1)
			local knob = New("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				Position = state and UDim2.new(1, -23, 0.5, -9) or UDim2.new(0, 4, 0.5, -9),
				Size = UDim2.fromOffset(18, 18),
				Parent = track,
			})
			Corner(knob, 9)
			New("UIGradient", {
				Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(230, 232, 240)),
				Rotation = 90,
				Parent = knob,
			})

			local handle = { Value = state }
			local function apply(v, silent)
				state = v and true or false
				handle.Value = state
				Tween(track, T_FAST, { BackgroundColor3 = state and theme.Accent or theme.Stroke })
				Tween(knob, T_FAST, { Position = state and UDim2.new(1, -23, 0.5, -9) or UDim2.new(0, 4, 0.5, -9) })
				Tween(glow, T_FAST, { Thickness = state and 5 or 0, Transparency = state and 0.7 or 1 })
				SetFlag(o.Flag or o.Title, state)
				if not silent and o.Callback then
					o.Callback(state)
				end
			end
			track.MouseButton1Click:Connect(function()
				apply(not state)
			end)
			function handle:Set(v)
				apply(v)
			end
			if o.Flag then
				setters[o.Flag] = apply
			end
			SetFlag(o.Flag or o.Title, state)
			return handle
		end

		function api:Slider(a, b, c, d, e)
			local o
			if type(a) == "table" then
				o = TableOpts(a, { Title = "Slider", Min = 0, Max = 100, Default = 0, Rounding = 0 })
			else
				o = { Title = a, Min = b or 0, Max = c or 100, Default = d or b or 0, Callback = e, Rounding = 0 }
			end
			local min, max = o.Min or 0, o.Max or 100
			local value = math.clamp(o.Default or min, min, max)
			if o.Flag and type(flags[o.Flag]) == "number" then
				value = flags[o.Flag]
			end
			local card = Card(page, o.Description and 84 or 74, o.Title)
			TitleBlock(card, o.Title, o.Description)
			local valueLab = New("TextLabel", {
				BackgroundColor3 = theme.Background,
				Font = FONT_B,
				Text = " " .. tostring(value) .. (o.Suffix or "") .. " ",
				TextColor3 = theme.Accent,
				TextSize = 12,
				AutomaticSize = Enum.AutomaticSize.X,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 12),
				Size = UDim2.fromOffset(0, 22),
				Parent = card,
			})
			Corner(valueLab, 7)
			Stroke(valueLab, theme.Stroke, 1, 0.4)

			local bar = New("Frame", {
				BackgroundColor3 = theme.Stroke,
				Position = UDim2.new(0, 16, 1, -20),
				Size = UDim2.new(1, -32, 0, 8),
				Parent = card,
			})
			Corner(bar, 4)
			local fill = New("Frame", {
				BackgroundColor3 = theme.Accent,
				Size = UDim2.new((value - min) / math.max(max - min, 1e-6), 0, 1, 0),
				Parent = bar,
			})
			Corner(fill, 4)
			Gradient(fill, theme.Accent, theme.Accent2, 0)
			local knob = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				Position = UDim2.new((value - min) / math.max(max - min, 1e-6), 0, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				ZIndex = 3,
				Parent = bar,
			})
			Corner(knob, 8)
			Stroke(knob, theme.Accent, 2, 0.15)

			local handle = { Value = value }
			local function round(n)
				local r = o.Rounding or 0
				if r <= 0 then
					return math.floor(n + 0.5)
				end
				local m = 10 ^ r
				return math.floor(n * m + 0.5) / m
			end
			local function apply(v, silent)
				value = round(math.clamp(v, min, max))
				handle.Value = value
				local alpha = (value - min) / math.max(max - min, 1e-6)
				fill.Size = UDim2.new(alpha, 0, 1, 0)
				knob.Position = UDim2.new(alpha, 0, 0.5, 0)
				valueLab.Text = " " .. tostring(value) .. (o.Suffix or "") .. " "
				SetFlag(o.Flag or o.Title, value)
				if not silent and o.Callback then
					o.Callback(value)
				end
			end
			local sliding = false
			local function fromX(x)
				local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
				apply(min + (max - min) * rel)
			end
			bar.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					sliding = true
					fromX(input.Position.X)
				end
			end)
			Bind(UserInputService.InputChanged, function(input)
				if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					fromX(input.Position.X)
				end
			end)
			Bind(UserInputService.InputEnded, function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					sliding = false
				end
			end)
			function handle:Set(v)
				apply(v)
			end
			if o.Flag then
				setters[o.Flag] = apply
			end
			SetFlag(o.Flag or o.Title, value)
			return handle
		end

		function api:Dropdown(a, b, c, d)
			local o = type(a) == "table" and TableOpts(a, { Title = "Dropdown", Options = {} })
				or { Title = a, Options = b or {}, Default = c, Callback = d }
			local options = o.Options or o.Values or {}
			local value = o.Default
			if type(value) == "number" then
				value = options[value]
			end
			if value == nil then
				value = options[1]
			end
			if o.Flag and flags[o.Flag] ~= nil then
				value = flags[o.Flag]
			end
			local card = Card(page, o.Description and 62 or 54, o.Title)
			TitleBlock(card, o.Title, o.Description)
			local btn = New("TextButton", {
				AutoButtonColor = false,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(148, 32),
				BackgroundColor3 = theme.Background,
				Font = FONT_R,
				Text = "  " .. tostring(value or "Select") .. "  ▾",
				TextColor3 = theme.Text,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = card,
			})
			Corner(btn, 9)
			Stroke(btn, theme.Stroke, 1, 0.3)

			local list = New("Frame", {
				Visible = false,
				BackgroundColor3 = theme.Surface,
				Position = UDim2.new(1, -162, 1, 8),
				Size = UDim2.fromOffset(148, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				ZIndex = 50,
				Parent = card,
			})
			Corner(list, 12)
			Stroke(list, theme.Stroke, 1, 0.15)
			Pad(list, 6, 6, 6, 6)
			New("UIListLayout", { Parent = list, Padding = UDim.new(0, 4) })

			local handle = { Value = value }
			local function apply(v, silent)
				value = v
				handle.Value = v
				btn.Text = "  " .. tostring(v) .. "  ▾"
				list.Visible = false
				SetFlag(o.Flag or o.Title, v)
				if not silent and o.Callback then
					o.Callback(v)
				end
			end
			local function rebuild(newOptions)
				options = newOptions or options
				for _, child in ipairs(list:GetChildren()) do
					if child:IsA("TextButton") then
						child:Destroy()
					end
				end
				for _, opt in ipairs(options) do
					local item = New("TextButton", {
						AutoButtonColor = false,
						BackgroundColor3 = opt == value and theme.CardHover or theme.Card,
						Font = FONT_R,
						Text = "  " .. tostring(opt),
						TextColor3 = theme.Text,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.new(1, 0, 0, 28),
						ZIndex = 51,
						Parent = list,
					})
					Corner(item, 8)
					item.MouseButton1Click:Connect(function()
						apply(opt)
					end)
				end
			end
			rebuild(options)
			btn.MouseButton1Click:Connect(function()
				list.Visible = not list.Visible
			end)
			function handle:Set(v)
				apply(v)
			end
			function handle:Refresh(newOptions)
				rebuild(newOptions)
			end
			if o.Flag then
				setters[o.Flag] = apply
			end
			SetFlag(o.Flag or o.Title, value)
			return handle
		end

		function api:Input(a, b, c)
			local o
			if type(a) == "table" then
				o = TableOpts(a, { Title = "Input", Placeholder = "Type here...", Default = "" })
			else
				o = {
					Title = a,
					Placeholder = type(b) == "string" and b or "Type here...",
					Callback = type(b) == "function" and b or c,
					Default = "",
				}
			end
			local card = Card(page, o.Description and 62 or 54, o.Title)
			TitleBlock(card, o.Title, o.Description)
			local box = New("TextBox", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(156, 32),
				BackgroundColor3 = theme.Background,
				Font = FONT_R,
				PlaceholderText = o.Placeholder or "",
				PlaceholderColor3 = theme.Muted,
				Text = tostring(o.Default or ""),
				TextColor3 = theme.Text,
				TextSize = 12,
				ClearTextOnFocus = false,
				Parent = card,
			})
			Corner(box, 9)
			local bst = Stroke(box, theme.Stroke, 1, 0.3)
			Pad(box, 10, 0, 10, 0)
			box.Focused:Connect(function()
				Tween(bst, T_FAST, { Color = theme.Accent, Transparency = 0.1 })
			end)
			box.FocusLost:Connect(function()
				Tween(bst, T_FAST, { Color = theme.Stroke, Transparency = 0.3 })
			end)
			local handle = { Value = box.Text }
			local function fire()
				handle.Value = box.Text
				SetFlag(o.Flag or o.Title, box.Text)
				if o.Callback then
					o.Callback(box.Text)
				end
			end
			if o.Finished then
				box.FocusLost:Connect(function(enter)
					if enter then
						fire()
					end
				end)
			else
				box:GetPropertyChangedSignal("Text"):Connect(fire)
			end
			function handle:Set(v)
				box.Text = tostring(v)
				fire()
			end
			if o.Flag then
				setters[o.Flag] = function(v, silent)
					box.Text = tostring(v)
					handle.Value = box.Text
					if not silent and o.Callback then
						o.Callback(box.Text)
					end
				end
			end
			SetFlag(o.Flag or o.Title, box.Text)
			return handle
		end

		function api:Keybind(a, b, c)
			local o = type(a) == "table" and TableOpts(a, { Title = "Keybind", Default = Enum.KeyCode.E })
				or { Title = a, Default = b or Enum.KeyCode.E, Callback = c }
			local key = o.Default
			if type(key) == "string" then
				key = Enum.KeyCode[key] or Enum.KeyCode.E
			end
			local card = Card(page, o.Description and 62 or 54, o.Title)
			TitleBlock(card, o.Title, o.Description)
			local btn = New("TextButton", {
				AutoButtonColor = false,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(100, 32),
				BackgroundColor3 = theme.Background,
				Font = FONT_B,
				Text = key.Name,
				TextColor3 = theme.Text,
				TextSize = 12,
				Parent = card,
			})
			Corner(btn, 9)
			Stroke(btn, theme.Stroke, 1, 0.3)
			local listening = false
			local handle = { Value = key }
			btn.MouseButton1Click:Connect(function()
				listening = true
				btn.Text = "..."
			end)
			Bind(UserInputService.InputBegan, function(input, gp)
				if listening and input.UserInputType == Enum.UserInputType.Keyboard then
					listening = false
					key = input.KeyCode
					handle.Value = key
					btn.Text = key.Name
					SetFlag(o.Flag or o.Title, key)
					return
				end
				if not listening and not gp and input.KeyCode == key then
					if o.Callback then
						o.Callback()
					end
				end
			end)
			function handle:Set(v)
				if type(v) == "string" then
					v = Enum.KeyCode[v]
				end
				if v then
					key, handle.Value, btn.Text = v, v, v.Name
				end
			end
			SetFlag(o.Flag or o.Title, key)
			return handle
		end

		function api:ColorPicker(a, b, c)
			local o = type(a) == "table" and TableOpts(a, { Title = "Color", Default = Color3.fromRGB(99, 162, 255) })
				or { Title = a, Default = b or Color3.fromRGB(99, 162, 255), Callback = c }
			local color = o.Default
			if o.Flag and typeof(flags[o.Flag]) == "Color3" then
				color = flags[o.Flag]
			end
			local card = Card(page, 92, o.Title)
			TitleBlock(card, o.Title, o.Description)
			local swatch = New("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -16, 0, 12),
				Size = UDim2.fromOffset(30, 30),
				BackgroundColor3 = color,
				Parent = card,
			})
			Corner(swatch, 9)
			Stroke(swatch, Color3.new(1, 1, 1), 1, 0.7)

			local function rgbBar(y, start, fillCol)
				local bg = New("Frame", {
					BackgroundColor3 = theme.Stroke,
					Position = UDim2.new(0, 16, 0, y),
					Size = UDim2.new(1, -58, 0, 7),
					Parent = card,
				})
				Corner(bg, 4)
				local fill = New("Frame", {
					BackgroundColor3 = fillCol,
					Size = UDim2.new(start, 0, 1, 0),
					Parent = bg,
				})
				Corner(fill, 4)
				return bg, fill
			end
			local bgR, fillR = rgbBar(52, color.R, Color3.fromRGB(255, 90, 90))
			local bgG, fillG = rgbBar(66, color.G, Color3.fromRGB(90, 220, 130))
			local bgB, fillB = rgbBar(80, color.B, Color3.fromRGB(90, 150, 255))
			local bars = {
				{ bgR, fillR, "R" },
				{ bgG, fillG, "G" },
				{ bgB, fillB, "B" },
			}

			local handle = { Value = color }
			local function apply(col, silent)
				color = col
				handle.Value = col
				swatch.BackgroundColor3 = col
				fillR.Size = UDim2.new(col.R, 0, 1, 0)
				fillG.Size = UDim2.new(col.G, 0, 1, 0)
				fillB.Size = UDim2.new(col.B, 0, 1, 0)
				SetFlag(o.Flag or o.Title, col)
				if not silent and o.Callback then
					o.Callback(col)
				end
			end
			for _, pack in ipairs(bars) do
				local bg, _, ch = pack[1], pack[2], pack[3]
				local dragging = false
				local function fromX(x)
					local rel = math.clamp((x - bg.AbsolutePosition.X) / math.max(bg.AbsoluteSize.X, 1), 0, 1)
					local r, g, bl = color.R, color.G, color.B
					if ch == "R" then
						r = rel
					elseif ch == "G" then
						g = rel
					else
						bl = rel
					end
					apply(Color3.new(r, g, bl))
				end
				bg.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = true
						fromX(input.Position.X)
					end
				end)
				Bind(UserInputService.InputChanged, function(input)
					if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
						fromX(input.Position.X)
					end
				end)
				Bind(UserInputService.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = false
					end
				end)
			end
			function handle:Set(v)
				apply(v)
			end
			if o.Flag then
				setters[o.Flag] = apply
			end
			SetFlag(o.Flag or o.Title, color)
			return handle
		end

		local function flagged(method)
			return function(_, flagOrOpts, maybeOpts)
				if type(flagOrOpts) == "string" and type(maybeOpts) == "table" then
					maybeOpts.Flag = maybeOpts.Flag or flagOrOpts
					return method(api, maybeOpts)
				end
				return method(api, flagOrOpts)
			end
		end
		api.AddButton = api.Button
		api.AddToggle = flagged(api.Toggle)
		api.AddSlider = flagged(api.Slider)
		api.AddDropdown = flagged(api.Dropdown)
		api.AddInput = flagged(api.Input)
		api.AddKeybind = flagged(api.Keybind)
		api.AddColorpicker = flagged(api.ColorPicker)
		api.AddParagraph = api.Paragraph
		api.AddSection = api.Section
		api.CreateButton, api.CreateToggle, api.CreateSlider = api.Button, api.Toggle, api.Slider
		api.CreateDropdown, api.CreateInput, api.CreateKeybind = api.Dropdown, api.Input, api.Keybind
		api.CreateColorPicker, api.CreateParagraph = api.ColorPicker, api.Paragraph
		api.CreateSection, api.CreateLabel, api.CreateDivider = api.Section, api.Label, api.Divider
		return api
	end

	function WindowApi:Tab(name, icon)
		local o = type(name) == "table" and name or { Title = name, Icon = icon }
		local title = o.Title or o.Name or "Tab"
		if pages[title] then
			return TabApi(pages[title])
		end
		local page = MakePage(title)
		pages[title] = page
		table.insert(tabOrder, title)

		local btn = New("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = theme.Sidebar,
			Size = UDim2.new(1, 0, 0, 40),
			Text = "",
			Parent = tabList,
		})
		Corner(btn, 11)
		local marker = New("Frame", {
			Name = "Marker",
			BackgroundColor3 = theme.Accent,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 5, 0.5, -9),
			Size = UDim2.fromOffset(3, 18),
			Parent = btn,
		})
		Corner(marker, 2)
		local well = New("Frame", {
			Name = "IconWell",
			BackgroundColor3 = theme.Card,
			Position = UDim2.new(0, 14, 0.5, -11),
			Size = UDim2.fromOffset(22, 22),
			Parent = btn,
		})
		Corner(well, 7)
		New("TextLabel", {
			BackgroundTransparency = 1,
			Font = FONT_B,
			Text = o.Icon or string.sub(title, 1, 1),
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = o.Icon and 11 or 12,
			Size = UDim2.fromScale(1, 1),
			Parent = well,
		})
		New("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			Font = FONT_M,
			Text = title,
			TextColor3 = theme.SubText,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 42, 0, 0),
			Size = UDim2.new(1, -48, 1, 0),
			Parent = btn,
		})
		tabButtons[title] = btn
		btn.MouseButton1Click:Connect(function()
			SelectTab(title)
		end)
		if not selectedTab then
			SelectTab(title)
		end
		return TabApi(page)
	end
	WindowApi.AddTab = WindowApi.Tab
	WindowApi.CreateTab = WindowApi.Tab

	pill.MouseButton1Click:Connect(function()
		SetOpen(true)
	end)
	Bind(UserInputService.InputBegan, function(input, gp)
		if not gp and input.KeyCode == opts.ToggleKey then
			WindowApi:Toggle()
		end
	end)

	-- corner resize
	local grip = New("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -4),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 8,
		Parent = window,
	})
	local resizing = false
	local startSize, startMouse
	grip.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = true
			startSize = window.AbsoluteSize
			startMouse = input.Position
		end
	end)
	Bind(UserInputService.InputChanged, function(input)
		if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
			local d = input.Position - startMouse
			local w = math.clamp(startSize.X + d.X, 520, 980)
			local h = math.clamp(startSize.Y + d.Y, 380, 760)
			window.Size = UDim2.fromOffset(w, h)
			shadowFar.Size = window.Size + UDim2.fromOffset(56, 56)
			shadowMid.Size = window.Size + UDim2.fromOffset(32, 32)
			shadowNear.Size = window.Size + UDim2.fromOffset(16, 16)
		end
	end)
	Bind(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = false
		end
	end)

	task.defer(LoadConfig)
	table.insert(self.Windows, WindowApi)
	return WindowApi
end

Tracium.CreateWindow = Tracium.Create
Tracium.new = Tracium.Create

function Tracium:Unload()
	for _, w in ipairs(self.Windows) do
		pcall(function()
			w:Destroy()
		end)
	end
	table.clear(self.Windows)
	if self._notifyGui then
		self._notifyGui:Destroy()
		self._notifyGui = nil
	end
end

return Tracium
