--[[==========================================================================]]
-- Tracium v2 · Components/Divider.lua
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
