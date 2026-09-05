--[[==========================================================================]]
-- Tracium v2 · Components/Slider.lua
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
