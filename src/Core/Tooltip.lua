--[[==========================================================================]]
-- Tracium v2 · Core/Tooltip.lua
-- A single shared tooltip card that follows the mouse after a short hover
-- delay. Themed, animated, clamped to the viewport.
--
--   Tooltip:Attach(guiObject, "Some helpful text")
--   Tooltip:Attach(guiObject, { Title = "Row", Content = "..." })
--   Tooltip:Detach(guiObject)
--   Tooltip:SetEnabled(false)  Tooltip:SetDelay(0.6)
--[[==========================================================================]]

return function(Shared)
	local Tooltip = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local UIS = Shared.Services.UserInputService

	Tooltip.Enabled = true
	Tooltip.Delay = 0.45

	local gui, card, titleLab, contentLab
	local current = nil      -- guiObject currently hovered
	local currentOpts = nil
	local hoverConn, moveConn
	local showToken = 0
	local attached = setmetatable({}, { __mode = "k" })

	local function ensureGui()
		if card and card.Parent then
			return
		end
		gui = Utility.New("ScreenGui", {
			Name = "TraciumTooltip",
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = 1200,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
		Utility.ProtectGui(gui)

		card = Utility.New("Frame", {
			Name = "Card",
			BackgroundColor3 = Theme:Get("Tooltip"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(0, 0, 0, 0),
			Visible = false,
			ZIndex = 10,
			Parent = gui,
		})
		Utility.Paint(card, "BackgroundColor3", "Tooltip")
		Utility.Round(card, 8)
		Utility.Stroke(card, "StrokeHover", 1, 0.4)
		Utility.Pad(card, 8, 6, 8, 6)

		local layout = Utility.ListLayout(card, { Padding = 2 })
		layout.VerticalAlignment = Enum.VerticalAlignment.Top

		titleLab = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.XY,
			Visible = false,
			ZIndex = 11,
			Parent = card,
		})
		Utility.Paint(titleLab, "TextColor3", "Text")

		contentLab = Utility.New("TextLabel", {
			Name = "Content",
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Theme:Get("SubText"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			RichText = false,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(0, 220, 0, 0),
			ZIndex = 11,
			Parent = card,
		})
		Utility.Paint(contentLab, "TextColor3", "SubText")
	end

	local function positionAt(mouse)
		local vp = (Shared.Services.Workspace.CurrentCamera and Shared.Services.Workspace.CurrentCamera.ViewportSize)
			or Vector2.new(1920, 1080)
		local w = math.max(card.AbsoluteSize.X, 60)
		local h = math.max(card.AbsoluteSize.Y, 24)
		local x = mouse.X + 16
		local y = mouse.Y + 18
		if x + w > vp.X - 8 then
			x = mouse.X - w - 14
		end
		if y + h > vp.Y - 8 then
			y = vp.Y - h - 10
		end
		card.Position = UDim2.fromOffset(x, y)
	end

	local function show(opts)
		showToken += 1
		local token = showToken
		local text = type(opts) == "table" and (opts.Content or opts.Text or "") or tostring(opts)
		local title = type(opts) == "table" and opts.Title or nil
		if text == "" and title == nil then
			return
		end
		ensureGui()
		titleLab.Visible = title ~= nil and title ~= ""
		titleLab.Text = title or ""
		contentLab.Text = text
		card.Visible = true
		card.BackgroundTransparency = 1
		titleLab.TextTransparency = 1
		contentLab.TextTransparency = 1
		positionAt(Vector2.new(UIS:GetMouseLocation().X, UIS:GetMouseLocation().Y + 36))
		if token ~= showToken then
			return
		end
		Tween:Play(card, "Fast", { BackgroundTransparency = 0.06 })
		Tween:Play(titleLab, "Fast", { TextTransparency = 0 })
		Tween:Play(contentLab, "Fast", { TextTransparency = 0 })
	end

	local function hide()
		showToken += 1
		if not card or not card.Parent or not card.Visible then
			return
		end
		Tween:Play(card, "Fast", { BackgroundTransparency = 1 })
		Tween:Play(titleLab, "Fast", { TextTransparency = 1 })
		Tween:Play(contentLab, "Fast", { TextTransparency = 1 })
		task.delay(0.2, function()
			if card and card.Parent then
				card.Visible = false
			end
		end)
	end

	function Tooltip:Attach(obj, opts)
		if attached[obj] then
			self:Detach(obj)
		end
		local enterConn, leaveConn
		enterConn = obj.MouseEnter:Connect(function()
			if not Tooltip.Enabled then
				return
			end
			current = obj
			currentOpts = opts
			local captured = obj
			task.delay(Tooltip.Delay, function()
				if current == captured and Tooltip.Enabled then
					show(currentOpts)
					if moveConn then
						moveConn:Disconnect()
					end
					moveConn = UIS.InputChanged:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement and card and card.Visible then
							positionAt(Vector2.new(input.Position.X, input.Position.Y + 36))
						end
					end)
				end
			end)
		end)
		leaveConn = obj.MouseLeave:Connect(function()
			if current == obj then
				current = nil
				currentOpts = nil
				hide()
				if moveConn then
					moveConn:Disconnect()
					moveConn = nil
				end
			end
		end)
		attached[obj] = { enterConn, leaveConn }
		return obj
	end

	function Tooltip:Detach(obj)
		local conns = attached[obj]
		if conns then
			for _, c in ipairs(conns) do
				c:Disconnect()
			end
			attached[obj] = nil
		end
		if current == obj then
			current = nil
			hide()
		end
	end

	function Tooltip:SetEnabled(v)
		Tooltip.Enabled = not not v
		if not v then
			hide()
		end
	end

	function Tooltip:IsEnabled()
		return Tooltip.Enabled
	end

	function Tooltip:SetDelay(sec)
		Tooltip.Delay = tonumber(sec) or 0.45
	end

	function Tooltip:Destroy()
		showToken += 1
		if gui then
			gui:Destroy()
			gui, card = nil, nil
		end
	end

	return Tooltip
end
