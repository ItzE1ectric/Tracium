--[[==========================================================================]]
-- Tracium v2 · Components/Dropdown.lua
-- Select one (or many, opts.Multi) values from a popup list. Searchable.
--
--   Section:Dropdown({ Title="Target", Values={"All","Closest","LowHP"},
--       Default="All", Multi=false, Flag="Target", Callback=fn })
--   handle:Refresh({...})  handle:Set("Closest")  handle:Get()
--[[==========================================================================]]

return function(Shared)
	local Dropdown = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	function Dropdown.New(scope, opts)
		opts = opts or {}
		local values = opts.Values or opts.Options or {}
		local multi = opts.Multi == true
		local selected -- string (single) | set table value->true (multi)

		if multi then
			selected = {}
			if type(opts.Default) == "table" then
				for _, v in ipairs(opts.Default) do
					selected[v] = true
				end
			end
		else
			selected = opts.Default
			if selected == nil then
				selected = opts.DefaultIndex and values[opts.DefaultIndex] or values[1]
			end
		end

		------------------------------------------------------------------
		-- Row card
		------------------------------------------------------------------
		local root = Utility.New("Frame", {
			Name = "Dropdown_" .. (opts.Title or "?"),
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

		local col = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.ListLayout(col, { Padding = 6 })

		local header = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = col,
		})
		Utility.ListLayout(header, { Direction = "Horizontal", Padding = 6, Vertical = "Center" })

		local title = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -140, 0, 18),
			Text = opts.Title or "Dropdown",
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = header,
		})
		Utility.Paint(title, "TextColor3", "Text")

		------------------------------------------------------------------
		-- Button
		------------------------------------------------------------------
		local btn = Utility.New("TextButton", {
			Name = "Button",
			BackgroundColor3 = Theme:Get("Input"),
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Theme:Get("Text"),
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(0, 132, 0, 24),
			Parent = header,
		})
		Utility.Paint(btn, "BackgroundColor3", "Input")
		Utility.Paint(btn, "TextColor3", "Text")
		Utility.Round(btn, 6)
		Utility.Stroke(btn, "Stroke", 1, 0.5)
		Utility.Pad(btn, 8, 0, 24, 0)

		local btnText = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 1, 0),
			Text = "(none)",
			Parent = btn,
		})
		Utility.Paint(btnText, "TextColor3", "Text")

		local chevron = Icons:Create("chevron-down", {
			Size = 12, Color = "Muted",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 4, 0.5, 0),
			Parent = btn, Name = "Chevron",
		})

		------------------------------------------------------------------
		-- Popup (in window popup layer)
		------------------------------------------------------------------
		local popup, searchBox, listFrame
		local isOpen = false
		local closePopup, openPopup

		local function displayText()
			if multi then
				local names = {}
				for _, v in ipairs(values) do
					if selected[v] then
						table.insert(names, tostring(v))
					end
				end
				if #names == 0 then
					return "(none)"
				end
				local txt = table.concat(names, ", ")
				if #txt > 22 then
					return #names .. " selected"
				end
				return txt
			end
			return selected ~= nil and tostring(selected) or "(none)"
		end

		local function refreshButton()
			btnText.Text = displayText()
		end

		local listeners = {}
		local function fire()
			if opts.Callback then
				task.spawn(function()
					if multi then
						local arr = {}
						for _, v in ipairs(values) do
							if selected[v] then
								table.insert(arr, v)
							end
						end
						pcall(opts.Callback, arr)
					else
						pcall(opts.Callback, selected)
					end
				end)
			end
			for _, fn in ipairs(listeners) do
				task.spawn(fn)
			end
		end

		local function notifyFlag()
			if not opts.Flag then
				return
			end
			if multi then
				local arr = {}
				for _, v in ipairs(values) do
					if selected[v] then
						table.insert(arr, v)
					end
				end
				Shared.Config:NotifyChange(opts.Flag, arr)
			else
				Shared.Config:NotifyChange(opts.Flag, selected)
			end
		end

		local function buildItems(filter)
			for _, c in ipairs(listFrame:GetChildren()) do
				if c:IsA("TextButton") then
					c:Destroy()
				end
			end
			local order = 0
			for _, v in ipairs(values) do
				local text = tostring(v)
				if filter == "" or text:lower():find(filter, 1, true) then
					order += 1
					local isSel = multi and selected[v] or (selected == v)
					local item = Utility.New("TextButton", {
						Name = "Opt_" .. text,
						BackgroundColor3 = isSel and Theme:Get("Element") or Theme:Get("Card"),
						Font = Enum.Font.GothamMedium,
						TextSize = 11,
						TextColor3 = isSel and Theme:Get("Text") or Theme:Get("SubText"),
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = "  " .. text,
						Size = UDim2.new(1, 0, 0, 22),
						AutoButtonColor = false,
						LayoutOrder = order,
						Parent = listFrame,
					})
					Utility.Paint(item, "BackgroundColor3", isSel and "Element" or "Card")
					Utility.Paint(item, "TextColor3", isSel and "Text" or "SubText")
					Utility.Round(item, 5)

					if multi then
						local check = Icons:Create(isSel and "check-square" or "square", {
							Size = 12,
							Color = isSel and "Accent" or "Muted",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -6, 0.5, 0),
							Parent = item,
						})
						item:SetAttribute("CheckIcon", true)
						_ = check
					elseif isSel then
						Icons:Create("check", {
							Size = 12, Color = "Accent",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -6, 0.5, 0),
							Parent = item,
						})
					end

					item.MouseEnter:Connect(function()
						Tween:Play(item, "Fast", { BackgroundColor3 = Theme:Get("ElementHover") })
					end)
					item.MouseLeave:Connect(function()
						local s = multi and selected[v] or (selected == v)
						Tween:Play(item, "Fast", { BackgroundColor3 = Theme:Get(s and "Element" or "Card") })
					end)
					item.MouseButton1Click:Connect(function()
						if multi then
							selected[v] = not selected[v] or nil
							if selected[v] == false then
								selected[v] = nil
							end
							refreshButton()
							notifyFlag()
							fire()
							buildItems(searchBox and searchBox.Text or "")
						else
							selected = v
							refreshButton()
							notifyFlag()
							fire()
							closePopup()
						end
					end)
				end
			end
		end

		openPopup = function()
			if isOpen or not scope.Window then
				return
			end
			isOpen = true
			Tween:Play(chevron, "Fast", { Rotation = 180 })

			popup = Utility.New("Frame", {
				Name = "DropdownPopup",
				BackgroundColor3 = Theme:Get("Surface"),
				BorderSizePixel = 0,
				Size = UDim2.new(0, btn.AbsoluteSize.X, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				GroupTransparency = 0,
				ClipsDescendants = true,
				ZIndex = 60,
				Parent = scope.Window.PopupLayer,
			})
			Utility.Paint(popup, "BackgroundColor3", "Surface")
			Utility.Round(popup, 8)
			Utility.Stroke(popup, "StrokeHover", 1, 0.3)
			Utility.Pad(popup, 6, 6, 6, 6)

			local pcol = Utility.New("Frame", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				Parent = popup,
			})
			Utility.ListLayout(pcol, { Padding = 4 })

			-- search
			local searchable = opts.Searchable or #values > 8
			if searchable then
				local searchWrap = Utility.New("Frame", {
					BackgroundColor3 = Theme:Get("Input"),
					Size = UDim2.new(1, 0, 0, 24),
					Parent = pcol,
				})
				Utility.Paint(searchWrap, "BackgroundColor3", "Input")
				Utility.Round(searchWrap, 6)
				searchBox = Utility.New("TextBox", {
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					TextSize = 11,
					TextColor3 = Theme:Get("Text"),
					PlaceholderText = "Search...",
					PlaceholderColor3 = Theme:Get("Muted"),
					Text = "",
					Size = UDim2.new(1, -26, 1, 0),
					Position = UDim2.new(0, 8, 0, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = searchWrap,
				})
				Utility.Paint(searchBox, "TextColor3", "Text")
				searchBox:GetPropertyChangedSignal("Text"):Connect(function()
					buildItems(searchBox.Text:lower())
				end)
			end

			local maxItems = math.min(#values, 7)
			listFrame = Utility.New("ScrollingFrame", {
				Name = "List",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, maxItems * 26),
				CanvasSize = UDim2.new(),
				ScrollBarThickness = 2,
				ScrollBarImageColor3 = Theme:Get("Muted"),
				Parent = pcol,
			})
			Utility.Paint(listFrame, "ScrollBarImageColor3", "Muted")
			local layout = Utility.ListLayout(listFrame, { Padding = 2 })
			Utility.ConnectCanvas(listFrame, layout)

			buildItems("")

			-- position popup under the button, clamped inside the window
			local rootAbs = scope.Window.Root.AbsolutePosition
			local rootSize = scope.Window.Root.AbsoluteSize
			local btnAbs = btn.AbsolutePosition
			local relX = btnAbs.X - rootAbs.X
			local relY = btnAbs.Y - rootAbs.Y + btn.AbsoluteSize.Y + 4
			local popupH = math.min(#values * 26 + (searchable and 34 or 0) + 16, 235)
			if relY + popupH > rootSize.Y - 10 then
				relY = math.max(btnAbs.Y - rootAbs.Y - popupH - 4, 4)
			end
			popup.Position = UDim2.new(0, relX, 0, relY)

			popup.GroupTransparency = 1
			Tween:Play(popup, "PanelSlide", { GroupTransparency = 0 })

			scope.Window:OpenPopupHandle(popup, function()
				closePopup()
			end)
		end

		closePopup = function()
			if not isOpen then
				return
			end
			isOpen = false
			Tween:Play(chevron, "Fast", { Rotation = 0 })
			if popup and popup.Parent then
				local p = popup
				Tween:Play(p, "Fast", { GroupTransparency = 1 })
				task.delay(0.15, function()
					if p.Parent then
						p:Destroy()
					end
				end)
			end
			popup = nil
		end

		btn.MouseButton1Click:Connect(function()
			if isOpen then
				closePopup()
			else
				openPopup()
			end
			Utility.Ripple(btn)
		end)

		refreshButton()

		------------------------------------------------------------------
		-- Public handle
		------------------------------------------------------------------
		local self = {
			Type = "Dropdown",
			Root = root,
			Flag = opts.Flag,
			Options = opts,
		}

		function self:Set(v, silent)
			if multi then
				selected = {}
				if type(v) == "table" then
					for _, item in ipairs(v) do
						selected[item] = true
					end
				end
			else
				selected = v
			end
			refreshButton()
			notifyFlag()
			if not silent then
				fire()
			end
		end

		function self:ConfigSet(v)
			-- stored value is a string or an array of strings
			if multi and type(v) == "table" then
				selected = {}
				for _, item in ipairs(v) do
					selected[item] = true
				end
			elseif not multi then
				selected = v
			end
			refreshButton()
		end

		function self:Get()
			if multi then
				local arr = {}
				for _, v in ipairs(values) do
					if selected[v] then
						table.insert(arr, v)
					end
				end
				return arr
			end
			return selected
		end

		function self:Refresh(newValues, keepSelection)
			values = newValues or values
			if not keepSelection then
				if multi then
					selected = {}
				else
					selected = values[1]
				end
			end
			refreshButton()
			if isOpen then
				buildItems(searchBox and searchBox.Text or "")
			end
		end

		function self:OnChanged(fn)
			table.insert(listeners, fn)
		end

		function self:Destroy()
			closePopup()
			root:Destroy()
			if self.Flag then
				Shared.Config:Unregister(self.Flag)
			end
		end

		if opts.Tooltip then
			Shared.Tooltip:Attach(root, opts.Tooltip)
		end
		if self.Flag then
			Shared.Config:Register(self)
		end

		return self
	end

	return Dropdown
end
