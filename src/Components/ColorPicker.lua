--[[==========================================================================]]
-- Tracium v2 · Components/ColorPicker.lua
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
