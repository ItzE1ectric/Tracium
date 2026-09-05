--[[==========================================================================]]
-- Tracium v2 · Components/Dialog.lua
-- Modal confirmation dialog inside a window overlay.
--
--   Dialog.Open(window, {
--       Title = "Unload UI?", Content = "This cannot be undone.",
--       Buttons = { {Label="Cancel"}, {Label="Unload", Primary=true, Danger=true, Callback=fn} },
--       Dismissible = true,  Icon = "alert-triangle",
--   })
--[[==========================================================================]]

return function(Shared)
	local Dialog = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	function Dialog.Open(window, opts)
		opts = opts or {}
		local host = window.DialogHost or window.PopupLayer
		if not host then
			return nil
		end

		local dim = Utility.New("TextButton", {
			Name = "DialogDim",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 80,
			AutoButtonColor = false,
			Parent = host,
		})
		Tween:Play(dim, "Fade", { BackgroundTransparency = 0.5 })

		local box = Utility.New("Frame", {
			Name = "DialogBox",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 320, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme:Get("Surface"),
			ZIndex = 81,
			Parent = dim,
		})
		Utility.Paint(box, "BackgroundColor3", "Surface")
		Utility.Round(box, 14)
		Utility.Stroke(box, "StrokeHover", 1, 0.3)
		Utility.Pad(box, 16, 14, 16, 14)

		local scale = Utility.New("UIScale", { Scale = 0.9, Parent = box })
		Tween:Play(scale, "Dialog", { Scale = 1 })

		local col = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = box,
		})
		Utility.ListLayout(col, { Padding = 6 })

		if opts.Icon then
			Icons:Create(opts.Icon, { Size = 20, Color = opts.IconColor or "Accent", Parent = col })
		end

		local title = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = Theme:Get("Text"),
			Text = opts.Title or "Confirm",
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			ZIndex = 82,
			Parent = col,
		})
		Utility.Paint(title, "TextColor3", "Text")

		if opts.Content and opts.Content ~= "" then
			local content = Utility.New("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextColor3 = Theme:Get("SubText"),
				Text = opts.Content,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				ZIndex = 82,
				Parent = col,
			})
			Utility.Paint(content, "TextColor3", "SubText")
		end

		local btnRow = Utility.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = col,
		})
		Utility.ListLayout(btnRow, {
			Direction = "Horizontal",
			Padding = 8,
			Horizontal = "Right",
		})
		Utility.Pad(btnRow, 0, 8, 0, 0)

		local handle = { _dim = dim }
		local closed = false

		function handle:Close()
			if closed then
				return
			end
			closed = true
			Tween:Play(dim, "Fade", { BackgroundTransparency = 1 })
			if scale and scale.Parent then
				Tween:Play(scale, "Fast", { Scale = 0.92 })
			end
			task.delay(0.18, function()
				if dim.Parent then
					dim:Destroy()
				end
			end)
			if opts.OnClose then
				pcall(opts.OnClose)
			end
		end

		local buttons = opts.Buttons or { { Label = "OK", Primary = true } }
		for i, spec in ipairs(buttons) do
			spec = type(spec) == "string" and { Label = spec } or spec
			local primary = spec.Primary or (i == #buttons and #buttons == 1)
			local danger = spec.Danger == true
			local btn = Utility.New("TextButton", {
				BackgroundColor3 = primary and Theme:Get("Accent")
					or danger and Theme:Get("Danger") or Theme:Get("Element"),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = (primary or danger) and Theme:Get("AccentText") or Theme:Get("Text"),
				Text = spec.Label or spec.Title or "OK",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 64, 0, 30),
				AutoButtonColor = false,
				ZIndex = 83,
				Parent = btnRow,
			})
			Utility.Paint(btn, "BackgroundColor3",
				primary and "Accent" or danger and "Danger" or "Element")
			Utility.Paint(btn, "TextColor3", (primary or danger) and "AccentText" or "Text")
			Utility.Round(btn, 7)
			Utility.Pad(btn, 12, 0, 12, 0)
			Utility.HoverTint(btn, "BackgroundColor3",
				primary and "Accent" or danger and "Danger" or "Element",
				primary and "Accent" or danger and "Danger" or "ElementHover")
			btn.MouseButton1Click:Connect(function()
				if spec.Callback then
					pcall(spec.Callback)
				end
				handle:Close()
			end)
		end

		if opts.Dismissible ~= false then
			dim.MouseButton1Click:Connect(function(input)
				-- only dismiss via clicks outside the box
				local boxPos = box.AbsolutePosition
				local boxSize = box.AbsoluteSize
				local m = input.Position
				if m.X < boxPos.X or m.X > boxPos.X + boxSize.X
					or m.Y < boxPos.Y or m.Y > boxPos.Y + boxSize.Y then
					handle:Close()
				end
			end)
		end

		return handle
	end

	return Dialog
end
