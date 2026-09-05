--[[==========================================================================]]
-- Tracium v2 · Components/Input.lua
-- Text input row: placeholder, clear button, numeric filter, max length,
-- focus ring animation, FireOn = "Change" | "Enter" | "FocusLost".
--
--   Section:Input({ Title="Name", Placeholder="player name", Flag="Name",
--       Callback=function(text, enterPressed) end })
--[[==========================================================================]]

return function(Shared)
	local Input = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons

	function Input.New(scope, opts)
		opts = opts or {}
		local value = tostring(opts.Default or "")

		local root = Utility.New("Frame", {
			Name = "Input_" .. (opts.Title or "?"),
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
		Utility.ListLayout(col, { Padding = 4 })

		local title = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 16),
			Text = opts.Title or "Input",
			Parent = col,
		})
		Utility.Paint(title, "TextColor3", "Text")

		local fieldWrap = Utility.New("Frame", {
			Name = "Field",
			BackgroundColor3 = Theme:Get("Input"),
			Size = UDim2.new(1, 0, 0, 28),
			Parent = col,
		})
		Utility.Paint(fieldWrap, "BackgroundColor3", "Input")
		Utility.Round(fieldWrap, 7)
		local fieldStroke = Utility.Stroke(fieldWrap, "Stroke", 1, 0.4)

		local box = Utility.New("TextBox", {
			Name = "TextBox",
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			PlaceholderText = opts.Placeholder or "Type...",
			PlaceholderColor3 = Theme:Get("Muted"),
			Text = value,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = opts.ClearTextOnFocus == true,
			Size = UDim2.new(1, -36, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			Parent = fieldWrap,
		})
		Utility.Paint(box, "TextColor3", "Text")
		Utility.Paint(box, "PlaceholderColor3", "Muted")

		-- clear button
		local clear = Utility.New("TextButton", {
			Name = "Clear",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -5, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 1,
			Text = "",
			Visible = value ~= "",
			AutoButtonColor = false,
			Parent = fieldWrap,
		})
		local clearIcon = Icons:Create("x", {
			Size = 12, Color = "Muted", Parent = clear,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		})
		clear.MouseButton1Click:Connect(function()
			box.Text = ""
			box:CaptureFocus()
		end)

		local self = {
			Type = "Input",
			Root = root,
			Flag = opts.Flag,
			Options = opts,
			Value = value,
		}

		local function filter(text)
			if opts.MaxCharacters and #text > opts.MaxCharacters then
				text = text:sub(1, opts.MaxCharacters)
			end
			if opts.Numeric then
				text = text:gsub("[^%d%.%-]", "")
			end
			return text
		end

		local listeners = {}
		local fireOn = opts.FireOn or (opts.EnterPressedOnly and "Enter") or "Change"

		local function fire(enterPressed)
			self.Value = box.Text
			if self.Flag then
				Shared.Config:NotifyChange(self.Flag, self.Value)
			end
			if opts.Callback then
				task.spawn(function()
					pcall(opts.Callback, self.Value, enterPressed)
				end)
			end
			for _, fn in ipairs(listeners) do
				task.spawn(fn, self.Value)
			end
		end

		box:GetPropertyChangedSignal("Text"):Connect(function()
			local filtered = filter(box.Text)
			if filtered ~= box.Text then
				box.Text = filtered
				return
			end
			clear.Visible = box.Text ~= ""
			if fireOn == "Change" then
				fire(false)
			end
		end)

		box.Focused:Connect(function()
			Tween:Play(fieldStroke, "Fast", { Color = Theme:Get("Accent"), Transparency = 0.1 })
		end)

		box.FocusLost:Connect(function(enter)
			Tween:Play(fieldStroke, "Fast", { Color = Theme:Get("Stroke"), Transparency = 0.4 })
			if fireOn == "FocusLost" or (fireOn == "Enter" and enter) then
				fire(enter)
			end
			if fireOn == "Change" and enter and opts.FinishOnEnter == true then
				fire(true)
			end
		end)

		function self:Set(text)
			box.Text = tostring(text or "")
		end
		function self:Get()
			return box.Text
		end
		function self:ConfigSet(v)
			box.Text = tostring(v or "")
			self.Value = box.Text
		end
		function self:SetPlaceholder(t)
			box.PlaceholderText = tostring(t)
		end
		function self:OnChanged(fn)
			table.insert(listeners, fn)
		end
		function self:Destroy()
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

	return Input
end
