--[[==========================================================================]]
-- Tracium v2 · Components/Button.lua
-- A clickable row element. Supports subtitle, icon, hold-to-confirm,
-- variants (default/danger/success), and a loading state.
--
--   Section:Button({ Title="Collect", Callback=fn, ... })
--   handle:Fire()   -- programmatic click
--[[==========================================================================]]

return function(Shared)
	local Button = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	local VARIANT = {
		Default = { Color = "Accent", Text = "AccentText" },
		Danger = { Color = "Danger", Text = "AccentText" },
		Success = { Color = "Success", Text = "AccentText" },
		Muted = { Color = "Element", Text = "Text" },
	}

	function Button.New(scope, opts)
		opts = opts or {}
		local variant = VARIANT[opts.Variant] or VARIANT.Default

		local root = Utility.New("Frame", {
			Name = "Button_" .. (opts.Title or "btn"),
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Card")
		Utility.Round(root, 8)
		Utility.Stroke(root, "Stroke", 1, 0.6)
		Utility.Pad(root, 10, 8, 10, 8)

		local clickArea = Utility.New("TextButton", {
			Name = "Hitbox",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 3,
			Parent = root,
		})

		local inner = Utility.New("Frame", {
			Name = "Inner",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.ListLayout(inner, { Padding = 2 })

		local titleRow = Utility.New("Frame", {
			Name = "TitleRow",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Parent = inner,
		})
		Utility.ListLayout(titleRow, { Direction = "Horizontal", Padding = 6, Vertical = "Center" })

		if opts.Icon then
			Icons:Create(opts.Icon, { Size = 14, Color = "SubText", Parent = titleRow })
		end

		local titleLabel = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Text = opts.Title or "Button",
			Parent = titleRow,
		})
		Utility.Paint(titleLabel, "TextColor3", "Text")

		-- right-aligned "run" chip
		local chip = Utility.New("TextLabel", {
			Name = "Chip",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 18),
			BackgroundColor3 = Theme:Get(variant.Color),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = Theme:Get(variant.Text),
			Text = " " .. (opts.Chip or "Run") .. " ",
			Parent = root,
		})
		Utility.Paint(chip, "BackgroundColor3", variant.Color)
		Utility.Paint(chip, "TextColor3", variant.Text)
		Utility.Round(chip, 4)

		-- description
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
				Parent = inner,
			})
			Utility.Paint(desc, "TextColor3", "SubText")
		end

		-- interactive states
		local hovered = false
		clickArea.MouseEnter:Connect(function()
			hovered = true
			Tween:Play(root, "Fast", { BackgroundColor3 = Theme:Get("CardHover") })
		end)
		clickArea.MouseLeave:Connect(function()
			hovered = false
			Tween:Play(root, "Fast", { BackgroundColor3 = Theme:Get("Card") })
		end)

		local respPress, respRelease
		clickArea.MouseButton1Down:Connect(function()
			respPress = Tween:Play(chip, "Micro", { BackgroundTransparency = 0.3 })
		end)
		clickArea.MouseButton1Up:Connect(function()
			if respPress then
				Tween:Play(chip, "Micro", { BackgroundTransparency = 0 })
			end
		end)

		local busy = false
		local function fire()
			if busy then
				return
			end
			if opts.HoldToConfirm then
				-- Double-click within 600ms required
				if root:GetAttribute("Armed") and (tick() - root:GetAttribute("ArmTime")) < 0.6 then
					root:SetAttribute("Armed", false)
					chip.Text = " " .. (opts.Chip or "Run") .. " "
				else
					root:SetAttribute("Armed", true)
					root:SetAttribute("ArmTime", tick())
					chip.Text = " Confirm? "
					Tween:Play(chip, "Fast", { BackgroundColor3 = Theme:Get("Warning") })
					task.delay(0.6, function()
						if root.Parent and root:GetAttribute("Armed") then
							root:SetAttribute("Armed", false)
							chip.Text = " " .. (opts.Chip or "Run") .. " "
							Tween:Play(chip, "Fast", { BackgroundColor3 = Theme:Get(variant.Color) })
						end
					end)
					return
				end
			end
			Utility.Ripple(root)
			if opts.LoadingLabel then
				busy = true
				local old = chip.Text
				chip.Text = " " .. opts.LoadingLabel .. " "
				task.delay(0.8, function()
					if chip.Parent then
						chip.Text = old
					end
					busy = false
				end)
			end
			if opts.Callback then
				local ok, err = pcall(opts.Callback)
				if not ok then
					Shared.Notify:Notify({
						Title = "Button Error",
						Content = tostring(err),
						Type = "Error",
						Duration = 4,
					})
				end
			end
		end
		clickArea.MouseButton1Click:Connect(fire)
		_ = respRelease

		if opts.Tooltip then
			Shared.Tooltip:Attach(root, opts.Tooltip)
		end

		local self = {
			Type = "Button",
			Root = root,
			Flag = opts.Flag,
			Options = opts,
			Value = false,
		}

		function self:Fire()
			fire()
		end

		function self:SetTitle(t)
			titleLabel.Text = t
		end

		function self:SetChip(text)
			chip.Text = " " .. tostring(text) .. " "
		end

		function self:Set(text) -- generic alias for SetTitle
			self:SetTitle(text)
		end

		function self:Get()
			return false
		end

		function self:Destroy()
			root:Destroy()
		end

		return self
	end

	return Button
end
