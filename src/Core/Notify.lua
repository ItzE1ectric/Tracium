--[[==========================================================================]]
-- Tracium v2 · Core/Notify.lua
-- Toast notification system: stacked cards in any screen corner, typed
-- (Info/Success/Warning/Error), animated, with action buttons, sticky mode,
-- progress bar that pauses on hover.
--
--   local n = Notify:Notify({
--       Title = "Saved", Content = "Config written.", Type = "Success",
--       Duration = 4,                          -- 0 = sticky until dismissed
--       Icon = "check",                         -- optional lucide override
--       Actions = { {Label="Undo", Callback=fn, Style="Primary"} },
--       OnDismiss = fn,
--   })
--   n:Dismiss()
--
--   Notify:SetPosition("TopRight" | "TopLeft" | "BottomRight" | "BottomLeft"
--                      | "TopCenter" | "BottomCenter")
--   Notify:Clear()
--[[==========================================================================]]

return function(Shared)
	local Notify = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	local MAX_VISIBLE = 6
	local DEFAULT_DURATION = 5

	local POSITION = "TopRight"
	local Positions = {
		TopRight     = { anchor = Vector2.new(1, 0), pos = UDim2.new(1, -16, 0, 16), vAlign = Enum.VerticalAlignment.Top,    hAlign = Enum.HorizontalAlignment.Right   },
		TopLeft      = { anchor = Vector2.new(0, 0), pos = UDim2.new(0, 16, 0, 16),  vAlign = Enum.VerticalAlignment.Top,    hAlign = Enum.HorizontalAlignment.Left    },
		BottomRight  = { anchor = Vector2.new(1, 1), pos = UDim2.new(1, -16, 1, -16),vAlign = Enum.VerticalAlignment.Bottom, hAlign = Enum.HorizontalAlignment.Right   },
		BottomLeft   = { anchor = Vector2.new(0, 1), pos = UDim2.new(0, 16, 1, -16), vAlign = Enum.VerticalAlignment.Bottom, hAlign = Enum.HorizontalAlignment.Left    },
		TopCenter    = { anchor = Vector2.new(0.5, 0), pos = UDim2.new(0.5, 0, 0, 16),  vAlign = Enum.VerticalAlignment.Top,    hAlign = Enum.HorizontalAlignment.Center },
		BottomCenter = { anchor = Vector2.new(0.5, 1), pos = UDim2.new(0.5, 0, 1, -16),vAlign = Enum.VerticalAlignment.Bottom, hAlign = Enum.HorizontalAlignment.Center },
	}

	local TypeInfo = {
		Info    = { Color = "Accent",  Icon = "info" },
		Success = { Color = "Success", Icon = "check-circle" },
		Warning = { Color = "Warning", Icon = "alert-triangle" },
		Error   = { Color = "Danger",  Icon = "alert-octagon" },
	}

	local gui = nil
	local stacks = {}       -- position name -> stack frame
	local visible = {}      -- position name -> array of cards
	local queues = {}       -- position name -> array of pending opts
	local active = {}       -- all live cards (for Clear)

	local function ensureGui()
		if gui and gui.Parent then
			return
		end
		gui = Utility.New("ScreenGui", {
			Name = "TraciumNotifications",
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = 1100,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
		Utility.ProtectGui(gui)
		gui.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				gui = nil
				stacks = {}
			end
		end)
	end

	local function stackFrame(pos)
		if stacks[pos] and stacks[pos].Parent then
			return stacks[pos]
		end
		ensureGui()
		local def = Positions[pos]
		local holder = Utility.New("Frame", {
			Name = "Stack_" .. pos,
			BackgroundTransparency = 1,
			AnchorPoint = def.anchor,
			Position = def.pos,
			Size = UDim2.new(0, 330, 1, -32),
			Parent = gui,
		})
		local layout = Utility.ListLayout(holder, {
			Padding = 10,
			Horizontal = pos:find("Left") and "Left" or (pos:find("Center") and "Center" or "Right"),
			Vertical = def.vAlign == Enum.VerticalAlignment.Bottom and "Bottom" or "Top",
		})
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		stacks[pos] = holder
		visible[pos] = visible[pos] or {}
		queues[pos] = queues[pos] or {}
		return holder
	end

	local function reflow(pos)
		local holder = stackFrame(pos)
		for i, card in ipairs(visible[pos]) do
			card.LayoutOrder = i
		end
		_ = holder
	end

	local function pumpQueue(pos)
		local holder = stackFrame(pos)
		while #visible[pos] < MAX_VISIBLE and #queues[pos] > 0 do
			local opts = table.remove(queues[pos], 1)
			Notify:_spawn(opts, holder, pos)
		end
		reflow(pos)
	end

	----------------------------------------------------------------------
	-- Card construction
	----------------------------------------------------------------------

	function Notify:_spawn(opts, holder, pos)
		local tinfo = TypeInfo[opts.Type] or TypeInfo.Info
		local fromRight = pos:find("Right") ~= nil

		local card = Utility.New("CanvasGroup", {
			Name = "Notification",
			BackgroundColor3 = Theme:Get("Surface"),
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			GroupTransparency = 1,
			Position = UDim2.new(0, fromRight and 40 or -40, 0, 0),
			Parent = holder,
		})
		Utility.Paint(card, "BackgroundColor3", "Surface")
		Utility.Round(card, 12)
		Utility.Stroke(card, "Stroke", 1, 0.45)

		-- left type bar
		local bar = Utility.New("Frame", {
			Name = "TypeBar",
			BackgroundColor3 = Theme:Get(tinfo.Color),
			BorderSizePixel = 0,
			Size = UDim2.new(0, 3, 1, 0),
			Parent = card,
		})
		Utility.Paint(bar, "BackgroundColor3", tinfo.Color)
		Utility.Round(bar, 2)

		local body = Utility.New("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(1, -10, 0, 0),
			Parent = card,
		})
		Utility.Pad(body, 10, 10, 10, 12)
		Utility.ListLayout(body, { Padding = 4 })

		-- icon + title row
		local titleRow = Utility.New("Frame", {
			Name = "TitleRow",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = body,
		})
		Utility.ListLayout(titleRow, { Direction = "Horizontal", Padding = 8, Vertical = "Top" })

		Icons:Create(opts.Icon or tinfo.Icon, {
			Size = 16, Color = tinfo.Color, Parent = titleRow,
			Name = "TypeIcon",
		})

		local titleLabel = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -46, 0, 0),
			Text = opts.Title or "Notification",
			Parent = titleRow,
		})
		Utility.Paint(titleLabel, "TextColor3", "Text")

		-- close button (dismissible)
		if opts.Dismissible ~= false then
			local close = Utility.New("TextButton", {
				Name = "Close",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(18, 18),
				Text = "",
				AutoButtonColor = false,
				Parent = titleRow,
			})
			local xIcon = Icons:Create("x", { Size = 12, Color = "Muted", Parent = close,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
			close.MouseEnter:Connect(function()
				Tween:Play(xIcon, "Fast", { ImageColor3 = Theme:Get("Text") })
			end)
			close.MouseLeave:Connect(function()
				Tween:Play(xIcon, "Fast", { ImageColor3 = Theme:Get("Muted") })
			end)
			close.MouseButton1Click:Connect(function()
				Notify:_dismiss(card)
			end)
		end

		-- content
		if opts.Content and opts.Content ~= "" then
			local content = Utility.New("TextLabel", {
				Name = "Content",
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextColor3 = Theme:Get("SubText"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, -24, 0, 0),
				Text = opts.Content,
				Parent = body,
			})
			Utility.Paint(content, "TextColor3", "SubText")
		end

		-- actions row
		if type(opts.Actions) == "table" and #opts.Actions > 0 then
			local row = Utility.New("Frame", {
				Name = "Actions",
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				Parent = body,
			})
			Utility.ListLayout(row, { Direction = "Horizontal", Padding = 6 })
			Utility.Pad(row, 0, 4, 0, 0)
			for _, action in ipairs(opts.Actions) do
				local primary = action.Style == "Primary" or action.Primary
				local danger = action.Style == "Danger" or action.Danger
				local btn = Utility.New("TextButton", {
					Name = "Action",
					BackgroundColor3 = primary and Theme:Get("Accent")
						or danger and Theme:Get("Danger") or Theme:Get("Element"),
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
					Text = action.Label or "OK",
					TextColor3 = (primary or danger) and Theme:Get("AccentText") or Theme:Get("Text"),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 0, 24),
					AutoButtonColor = false,
					Parent = row,
				})
				Utility.Paint(btn, "BackgroundColor3",
					primary and "Accent" or danger and "Danger" or "Element")
				Utility.Paint(btn, "TextColor3", (primary or danger) and "AccentText" or "Text")
				Utility.Round(btn, 6)
				Utility.Pad(btn, 10, 0, 10, 0)
				Utility.HoverTint(btn, "BackgroundColor3",
					primary and "Accent" or danger and "Danger" or "Element",
					primary and "Accent" or danger and "Danger" or "ElementHover")
				btn.MouseButton1Click:Connect(function()
					Utility.Ripple(btn)
					if action.Callback then
						pcall(action.Callback)
					end
					if action.DismissOnClick ~= false then
						Notify:_dismiss(card)
					end
				end)
			end
		end

		-- progress bar (non-sticky)
		local fillProgress = nil
		if (opts.Duration or DEFAULT_DURATION) > 0 then
			local track = Utility.New("Frame", {
				Name = "ProgressTrack",
				BackgroundColor3 = Theme:Get("Divider"),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -2),
				Size = UDim2.new(1, 0, 0, 2),
				Parent = card,
			})
			Utility.Paint(track, "BackgroundColor3", "Divider")
			local fill = Utility.New("Frame", {
				Name = "Fill",
				BackgroundColor3 = Theme:Get(tinfo.Color),
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 1, 0),
				Parent = track,
			})
			Utility.Paint(fill, "BackgroundColor3", tinfo.Color)
			local duration = opts.Duration or DEFAULT_DURATION
			local remaining = duration
			local resumedAt = nil
			local function playProgress()
				if fillProgress then
					fillProgress:Cancel()
				end
				if remaining <= 0 then
					return
				end
				resumedAt = tick()
				-- tween from CURRENT fill scale to full over `remaining` seconds
				fillProgress = Shared.Services.TweenService:Create(
					fill,
					TweenInfo.new(remaining, Enum.EasingStyle.Linear),
					{ Size = UDim2.new(1, 0, 1, 0) }
				)
				fillProgress:Play()
			end
			card.MouseEnter:Connect(function()
				if fillProgress and resumedAt then
					remaining = math.max(remaining - (tick() - resumedAt), 0)
					fillProgress:Pause()
				end
			end)
			card.MouseLeave:Connect(function()
				playProgress()
			end)
			playProgress()
			task.delay(duration + 0.1, function()
				if card.Parent then
					Notify:_dismiss(card)
				end
			end)
		end

		-- entrance animation
		Tween:Play(card, "PanelSlide", { Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0 })

		table.insert(visible[pos], card)
		active[card] = pos

		return card
	end

	function Notify:_dismiss(card)
		if not card or not card.Parent then
			return
		end
		local pos = active[card]
		active[card] = nil
		if pos then
			for i, c in ipairs(visible[pos] or {}) do
				if c == card then
					table.remove(visible[pos], i)
					break
				end
		end
		end
		Tween:Play(card, "Fade", { GroupTransparency = 1 })
		task.delay(0.24, function()
			if card and card.Parent then
				card:Destroy()
			end
			if pos then
				pumpQueue(pos)
			end
		end)
	end

	----------------------------------------------------------------------
	-- Public API
	----------------------------------------------------------------------

	function Notify:Notify(opts)
		if type(opts) == "string" then
			opts = { Title = "Tracium", Content = opts }
		end
		opts = opts or {}
		opts.Type = opts.Type or "Info"
		local pos = opts.Position or POSITION
		local holder = stackFrame(pos)

		local count = #visible[pos]
		if count >= MAX_VISIBLE then
			table.insert(queues[pos], opts)
			return {
				Dismiss = function() end,
				_root = nil,
			}
		end

		local card = self:_spawn(opts, holder, pos)
		reflow(pos)
		local handle = { _root = card }
		function handle:Dismiss()
			Notify:_dismiss(card)
		end
		function handle:Update(newOpts)
			if not card or not card.Parent then
				return
			end
			if newOpts.Title then
				card.Body.TitleRow.Title.Text = newOpts.Title
			end
			if newOpts.Content and card.Body:FindFirstChild("Content") then
				card.Body.Content.Text = newOpts.Content
			end
		end
		return handle
	end

	function Notify:SetPosition(pos)
		if Positions[pos] then
			POSITION = pos
		end
	end

	function Notify:GetPosition()
		return POSITION
	end

	function Notify:Clear()
		for card in pairs(active) do
			Notify:_dismiss(card)
		end
	end

	function Notify:ClearAll()
		Notify:Clear()
	end

	-- allow Notify({...}) shorthand
	return setmetatable(Notify, {
		__call = function(_, opts)
			return Notify:Notify(opts)
		end,
	})
end
