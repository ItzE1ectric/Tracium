--[[==========================================================================]]
-- Tracium v2 · Addons/KeybindList.lua
-- Floating, draggable panel listing every live keybind (mspaint style).
--
--   local list = KeybindList:Show()
--   KeybindList:Hide(); KeybindList:Toggle()
--[[==========================================================================]]

return function(Shared)
	local KL = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	local gui, panel, listScroll
	local visible = false

	local function build()
		gui = Utility.New("ScreenGui", {
			Name = "TraciumKeybindList",
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = 800,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
		Utility.ProtectGui(gui)

		panel = Utility.New("Frame", {
			Name = "Panel",
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 16, 0.35, 0),
			Size = UDim2.new(0, 200, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme:Get("Surface"),
			Visible = false,
			Parent = gui,
		})
		Utility.Paint(panel, "BackgroundColor3", "Surface")
		Utility.Round(panel, 10)
		Utility.Stroke(panel, "Stroke", 1, 0.4)

		local head = Utility.New("Frame", {
			Name = "Head",
			BackgroundColor3 = Theme:Get("Card"),
			Size = UDim2.new(1, 0, 0, 26),
			Parent = panel,
		})
		Utility.Paint(head, "BackgroundColor3", "Card")
		Utility.Round(head, 10)
		local title = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Theme:Get("Text"),
			Text = "Keybinds",
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(1, -40, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = head,
		})
		Utility.Paint(title, "TextColor3", "Text")

		Icons:Create("keyboard", { Size = 13, Color = "Accent", AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0), Parent = head })

		listScroll = Utility.New("ScrollingFrame", {
			Name = "List",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 26),
			Size = UDim2.new(1, 0, 0, 0),
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 2,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = panel,
		})
		Utility.Paint(listScroll, "ScrollBarImageColor3", "Muted")
		Utility.ListLayout(listScroll, { Padding = 0 })
		Utility.Pad(listScroll, 4, 4, 4, 4)

		Shared.Drag:MakeDraggable(head, panel, { Lerp = 0.35 })

		-- keep list fresh
		local refresh = Utility.Debounce(0.12, function()
			if not visible then
				return
			end
			for _, c in ipairs(listScroll:GetChildren()) do
				if c:IsA("Frame") then
					c:Destroy()
				end
			end
			local any = false
			for _, entry in ipairs(Shared.Keybinds or {}) do
				any = true
				local row = Utility.New("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 18),
					Parent = listScroll,
				})
				local name = Utility.New("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					TextSize = 11,
					TextColor3 = Theme:Get("SubText"),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Size = UDim2.new(1, -70, 1, 0),
					Text = entry.Title,
					Parent = row,
				})
				Utility.Paint(name, "TextColor3", "SubText")

				local keyName = "None"
				local kb = entry.Ref
				if kb and kb.Value then
					keyName = Utility.KeyName(kb.Value)
				end

				local chip = Utility.New("TextLabel", {
					BackgroundColor3 = Theme:Get("Input"),
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					TextColor3 = Theme:Get("Text"),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 30, 1, -2),
					Text = " " .. keyName .. " ",
					Parent = row,
				})
				Utility.Paint(chip, "BackgroundColor3", "Input")
				Utility.Paint(chip, "TextColor3", "Text")
				Utility.Round(chip, 4)
			end
			if not any then
				local row = Utility.New("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					TextSize = 11,
					TextColor3 = Theme:Get("Muted"),
					Text = "No keybinds",
					Size = UDim2.new(1, 0, 0, 18),
					Parent = listScroll,
				})
				Utility.Paint(row, "TextColor3", "Muted")
			end
		end)
		Shared.RefreshKeybindList = refresh
	end

	function KL:Show()
		if not gui then
			build()
		end
		visible = true
		if panel then
			panel.Visible = true
			panel.GroupTransparency = nil
			Tween:Play(panel, "PanelSlide", { Position = UDim2.new(0, 16, 0.35, 0) })
		end
		if Shared.RefreshKeybindList then
			Shared.RefreshKeybindList()
		end
	end

	function KL:Hide()
		visible = false
		if panel then
			Tween:Play(panel, "Fade", { Position = UDim2.new(0, 16, 0.4, 0) })
			task.delay(0.2, function()
				if panel then
					panel.Visible = false
				end
			end)
		end
	end

	function KL:Toggle()
		if visible then
			KL:Hide()
		else
			KL:Show()
		end
	end

	function KL:IsVisible()
		return visible
	end

	-- refresh when keybinds change
	task.spawn(function()
		while true do
			task.wait(0.5)
			if visible and Shared.RefreshKeybindList then
				Shared.RefreshKeybindList()
			end
		end
	end)

	return KL
end
