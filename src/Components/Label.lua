--[[==========================================================================]]
-- Tracium v2 · Components/Label.lua
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
