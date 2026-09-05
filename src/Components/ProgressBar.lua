--[[==========================================================================]]
-- Tracium v2 · Components/ProgressBar.lua
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
