--[[==========================================================================]]
-- Tracium v2 · Components/Toggle.lua
-- Animated switch (or checkbox) with optional description, tooltip,
-- and attachable mini-controls via :AddKeybind / :AddColorPicker chips.
--
--   local t = Section:Toggle({ Title="Aimbot", Default=false, Flag="Aimbot",
--                              Mode="Toggle", Callback=function(v) end })
--   t:Set(true);  t:AddKeybind({ Flag="AimbotKey" })  t:AddColorPicker{...}
--[[==========================================================================]]

return function(Shared)
	local Toggle = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	function Toggle.New(scope, opts)
		opts = opts or {}
		local value = opts.Default == true
		local listeners = {}

		local root = Utility.New("Frame", {
			Name = "Toggle_" .. (opts.Title or "?"),
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Card")
		Utility.Round(root, 8)
		Utility.Stroke(root, "Stroke", 1, 0.6)

		local body = Utility.New("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.Pad(body, 10, 8, 10, 8)
		Utility.ListLayout(body, { Padding = 2 })

		local titleRow = Utility.New("Frame", {
			Name = "Row",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = body,
		})
		Utility.ListLayout(titleRow, { Direction = "Horizontal", Padding = 6, Vertical = "Center" })

		local titleLabel = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -110, 0, 0),
			Text = opts.Title or "Toggle",
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = titleRow,
		})
		Utility.Paint(titleLabel, "TextColor3", "Text")

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
				Parent = body,
			})
			Utility.Paint(desc, "TextColor3", "SubText")
		end

		-- sub-control chips live right of the title row, before the switch
		local chips = Utility.New("Frame", {
			Name = "Chips",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 20),
			LayoutOrder = 2,
			Parent = titleRow,
		})
		Utility.ListLayout(chips, { Direction = "Horizontal", Padding = 4, Horizontal = "Right", Vertical = "Center" })

		------------------------------------------------------------------
		-- Switch control
		------------------------------------------------------------------
		local switch = Utility.New("TextButton", {
			Name = "Switch",
			BackgroundColor3 = value and Theme:Get("Accent") or Theme:Get("Element"),
			Size = UDim2.new(0, 38, 0, 20),
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = 3,
			Parent = titleRow,
		})
		Utility.Round(switch, 10)
		local switchStroke = Utility.Stroke(switch, value and "Accent" or "StrokeHover", 1, 0.4)

		local knob = Utility.New("Frame", {
			Name = "Knob",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Position = value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.new(0, 14, 0, 14),
			Parent = switch,
		})
		Utility.Round(knob, 7)
		Utility.Gradient(knob, Color3.new(1, 1, 1), Color3.fromRGB(225, 228, 238), 90)

		local function paintSwitch(v, animate)
			local trackColor = v and Theme:Get("Accent") or Theme:Get("Element")
			local strokeKey = v and "Accent" or "StrokeHover"
			if animate then
				Tween:Play(switch, "Fast", { BackgroundColor3 = trackColor })
				Tween:Play(knob, "Spring", { Position = v and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
				Tween:Play(knob, "Fast", { Size = v and UDim2.new(0, 16, 0, 16) or UDim2.new(0, 14, 0, 14) })
			else
				switch.BackgroundColor3 = trackColor
				knob.Position = v and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
			end
			Utility.Paint(switch, "BackgroundColor3", v and "Accent" or "Element")
			Utility.Paint(switchStroke, "Color", strokeKey)
		end

		local self = {
			Type = "Toggle",
			Root = root,
			Flag = opts.Flag,
			Options = opts,
			Value = value,
		}

		local function setInternal(v, silent, animate)
			value = not not v
			self.Value = value
			paintSwitch(value, animate ~= false)
			if self.Flag then
				Shared.Config:NotifyChange(self.Flag, value)
			end
			if not silent then
				if opts.Callback then
					task.spawn(function()
						local ok, err = pcall(opts.Callback, value)
						if not ok then
							Shared.Notify:Notify({ Title = "Toggle Error", Content = tostring(err), Type = "Error" })
						end
					end)
				end
				for _, fn in ipairs(listeners) do
					task.spawn(fn, value)
				end
			end
		end

		switch.MouseButton1Click:Connect(function()
			Utility.Ripple(switch)
			setInternal(not value)
		end)

		-- whole row clicks (except when clicking a chip)
		local rowBtn = Utility.New("TextButton", {
			Name = "RowClick",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -60, 1, 0),
			Text = "",
			ZIndex = 1,
			Parent = root,
		})
		titleRow.ZIndex = 3
		switch.ZIndex = 4
		rowBtn.MouseButton1Click:Connect(function()
			setInternal(not value)
		end)
		rowBtn.MouseEnter:Connect(function()
			Tween:Play(root, "Fast", { BackgroundColor3 = Theme:Get("CardHover") })
		end)
		rowBtn.MouseLeave:Connect(function()
			Tween:Play(root, "Fast", { BackgroundColor3 = Theme:Get("Card") })
		end)

		function self:Set(v)
			setInternal(v, false, true)
		end

		function self:SetQuiet(v)
			setInternal(v, true, false)
		end

		function self:ConfigSet(v)
			setInternal(v == true, true, false)
		end

		function self:Get()
			return value
		end

		function self:OnChanged(fn)
			table.insert(listeners, fn)
			return function()
				for i, f in ipairs(listeners) do
					if f == fn then
						table.remove(listeners, i)
						break
					end
				end
			end
		end

		-- keybind mini-chip below the row (Linoria style)
		function self:AddKeybind(kopts)
			kopts = kopts or {}
			kopts.Title = kopts.Title or (opts.Title .. " Key")
			kopts.Mode = kopts.Mode or "Toggle"
			kopts._embeddedToggle = self
			local kb = Shared.Components.Keybind.NewEmbedding(scope, kopts, chips)
			if kopts.Flag then
				Shared.Config:Register(kb)
			end
			return kb
		end

		function self:AddColorPicker(copts)
			copts = copts or {}
			copts.Title = copts.Title or (opts.Title .. " Color")
			local cp = Shared.Components.ColorPicker.NewEmbedding(scope, copts, chips)
			if copts.Flag then
				Shared.Config:Register(cp)
			end
			return cp
		end

		if opts.Tooltip then
			Shared.Tooltip:Attach(root, opts.Tooltip)
		end

		-- config bootstrap
		if self.Flag then
			Shared.Config:Register(self)
		end

		function self:Destroy()
			root:Destroy()
			if self.Flag then
				Shared.Config:Unregister(self.Flag)
			end
		end

		return self
	end

	return Toggle
end
