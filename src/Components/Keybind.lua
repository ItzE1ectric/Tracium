--[[==========================================================================]]
-- Tracium v2 · Components/Keybind.lua
-- Key picker with modes (Toggle / Hold / Always). Click chip to rebind,
-- Esc cancels, Backspace/Delete unbinds. Hold mode fires on press/release.
--
--   local kb = Section:Keybind({ Title="Fly", Default="F", Flag="FlyKey",
--       Mode="Toggle", Callback=function(active) end })
--   kb:SetKey(Enum.KeyCode.Q)
--
-- Also provides Keybind.NewEmbedding(scope, opts, parent) — compact chip
-- used by Toggle:AddKeybind().
--[[==========================================================================]]

return function(Shared)
	local Keybind = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local UIS = Shared.Services.UserInputService

	Shared.Keybinds = Shared.Keybinds or {} -- registry for the KeybindList addon

	----------------------------------------------------------------------
	-- Core logic factory (shared by card + embedded forms)
	----------------------------------------------------------------------

	local function MakeBinder(handle, opts)
		handle.Value = opts.Default or nil
		handle.Mode = opts.Mode or "Toggle" -- Toggle | Hold | Always
		handle.State = false -- current activation state

		local listening = false

		function handle:IsListening()
			return listening
		end

		function handle:SetListening(v)
			listening = v
		end

		function handle:SetKey(key, silent)
			if type(key) == "string" then
				key = Utility.KeyFromName(key)
			end
			handle.Value = key
			if handle._paint then
				handle._paint()
			end
			if handle.Flag then
				local encoded = key and key.Name or "None"
				Shared.Config:NotifyChange(handle.Flag, encoded)
			end
			if not silent and opts.Callback and handle.Mode == "Always" and key == nil then
				-- unbinding an Always bind = deactivate
				handle.State = false
			end
		end

		function handle:GetKey()
			return handle.Value
		end

		function handle:GetState()
			return handle.State
		end

		function handle:SetMode(m)
			if m == "Toggle" or m == "Hold" or m == "Always" then
				handle.Mode = m
				if handle._paint then
					handle._paint()
				end
			end
		end

		local function activate(active)
			handle.State = active
			if opts.Callback then
				task.spawn(function()
					pcall(opts.Callback, active)
				end)
			end
			if handle._onState then
				handle._onState(active)
			end
		end

		function handle:_press()
			if handle.Mode == "Toggle" then
				activate(not handle.State)
			elseif handle.Mode == "Hold" then
				activate(true)
			else
				activate(true)
			end
			if opts.OnPress then
				pcall(opts.OnPress)
			end
		end

		function handle:_release()
			if handle.Mode == "Hold" then
				activate(false)
			end
			if opts.OnRelease then
				pcall(opts.OnRelease)
			end
		end

		-- global input listening
		local conns = {}
		table.insert(conns, UIS.InputBegan:Connect(function(input, gpe)
			if listening then
				if input.UserInputType == Enum.UserInputType.Keyboard then
					local kc = input.KeyCode
					if kc == Enum.KeyCode.Escape then
						listening = false
						if handle._paint then
							handle._paint()
						end
						return
					end
					if kc == Enum.KeyCode.Backspace or kc == Enum.KeyCode.Delete then
						listening = false
						handle:SetKey(nil)
						return
					end
					listening = false
					handle:SetKey(kc)
				end
				return
			end
			if gpe or Utility.IsTyping() then
				return
			end
			if handle.Value and input.KeyCode == handle.Value then
				handle:_press()
			end
		end))
		table.insert(conns, UIS.InputEnded:Connect(function(input)
			if handle.Value and input.KeyCode == handle.Value then
				handle:_release()
			end
		end))

		function handle:_destroyConns()
			for _, c in ipairs(conns) do
				c:Disconnect()
			end
		end

		-- register for KeybindList addon
		local entry = { Title = opts.Title or "Keybind", Ref = handle }
		table.insert(Shared.Keybinds, entry)
		handle._entry = entry

		function handle:_unregister()
			for i, e in ipairs(Shared.Keybinds) do
				if e == entry then
					table.remove(Shared.Keybinds, i)
					break
				end
			end
		end

		function handle:ConfigSet(encoded)
			if encoded == "None" or encoded == nil then
				handle:SetKey(nil, true)
			elseif type(encoded) == "string" then
				handle:SetKey(Utility.KeyFromName(encoded), true)
			elseif typeof(encoded) == "EnumItem" then
				handle:SetKey(encoded, true)
			end
		end

		return handle
	end

	----------------------------------------------------------------------
	-- Full-row keybind card
	----------------------------------------------------------------------

	function Keybind.New(scope, opts)
		opts = opts or {}
		local root = Utility.New("Frame", {
			Name = "Keybind_" .. (opts.Title or "?"),
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

		local row = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.ListLayout(row, { Direction = "Horizontal", Padding = 6, Vertical = "Center" })

		local title = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -90, 0, 0),
			Text = opts.Title or "Keybind",
			Parent = row,
		})
		Utility.Paint(title, "TextColor3", "Text")

		-- mode cycle button
		local modeBtn = Utility.New("TextButton", {
			Name = "Mode",
			BackgroundColor3 = Theme:Get("Element"),
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextColor3 = Theme:Get("Muted"),
			Text = " Toggle ",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 18),
			AutoButtonColor = false,
			Parent = row,
		})
		Utility.Paint(modeBtn, "BackgroundColor3", "Element")
		Utility.Paint(modeBtn, "TextColor3", "Muted")
		Utility.Round(modeBtn, 4)

		-- key chip
		local chip = Utility.New("TextButton", {
			Name = "Key",
			BackgroundColor3 = Theme:Get("Input"),
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Theme:Get("Text"),
			Text = " None ",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 36, 0, 20),
			AutoButtonColor = false,
			Parent = row,
		})
		Utility.Paint(chip, "BackgroundColor3", "Input")
		Utility.Paint(chip, "TextColor3", "Text")
		Utility.Round(chip, 5)
		Utility.Stroke(chip, "Stroke", 1, 0.5)

		local handle = {
			Type = "Keybind",
			Root = root,
			Flag = opts.Flag,
			Options = opts,
		}
		MakeBinder(handle, opts)

		function handle._paint()
			chip.Text = " " .. Utility.KeyName(handle.Value) .. " "
			modeBtn.Text = " " .. handle.Mode .. " "
			if handle:IsListening() then
				chip.Text = " ... "
				Tween:Play(chip, "Fast", { BackgroundColor3 = Theme:Get("Accent") })
			else
				Tween:Play(chip, "Fast", { BackgroundColor3 = Theme:Get("Input") })
			end
		end

		chip.MouseButton1Click:Connect(function()
			if handle:IsListening() then
				handle:SetListening(false)
			else
				handle:SetListening(true)
			end
			handle._paint()
		end)

		modeBtn.MouseButton1Click:Connect(function()
			Utility.Ripple(modeBtn)
			local order = { "Toggle", "Hold", "Always" }
			local idx = table.find(order, handle.Mode) or 1
			handle:SetMode(order[idx % 3 + 1])
			handle._paint()
		end)
		if opts.AllowModeCycle == false then
			modeBtn.Visible = false
			title.Size = UDim2.new(1, -60, 0, 0)
		end

		handle._paint()

		if opts.Tooltip then
			Shared.Tooltip:Attach(root, opts.Tooltip)
		end

		function handle:Set(key)
			handle:SetKey(key)
		end
		function handle:Get()
			return handle.Value and handle.Value.Name or "None"
		end
		function handle:Destroy()
			handle:_destroyConns()
			handle:_unregister()
			root:Destroy()
		end

		if opts.Flag then
			Shared.Config:Register(handle)
		end

		return handle
	end

	-- (see note in file footer: self_flag_guard is defined below)

	----------------------------------------------------------------------
	-- Embedded chip form (used by Toggle:AddKeybind)
	----------------------------------------------------------------------

	function Keybind.NewEmbedding(scope, opts, parent)
		opts = opts or {}
		local chip = Utility.New("TextButton", {
			Name = "KeyChip",
			BackgroundColor3 = Theme:Get("Input"),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = Theme:Get("Text"),
			Text = " None ",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 26, 0, 16),
			AutoButtonColor = false,
			Parent = parent,
		})
		Utility.Paint(chip, "BackgroundColor3", "Input")
		Utility.Paint(chip, "TextColor3", "Text")
		Utility.Round(chip, 4)
		Utility.Stroke(chip, "Stroke", 1, 0.5)

		local handle = {
			Type = "KeybindChip",
			Root = chip,
			Flag = opts.Flag,
			Options = opts,
		}
		MakeBinder(handle, opts)
		if opts.Mode then
			handle:SetMode(opts.Mode)
		end

		function handle._paint()
			chip.Text = " " .. Utility.KeyName(handle.Value) .. " "
		end
		handle._paint()

		chip.MouseButton1Click:Connect(function()
			handle:SetListening(not handle:IsListening())
			chip.Text = handle:IsListening() and " ... " or (" " .. Utility.KeyName(handle.Value) .. " ")
			Tween:Play(chip, "Fast", {
				BackgroundColor3 = handle:IsListening() and Theme:Get("Accent") or Theme:Get("Input"),
			})
		end)

		-- when the owning toggle flips, optionally activate bind state
		if opts._embeddedToggle and handle.Mode == "Toggle" then
			opts._embeddedToggle:OnChanged(function(v)
				-- keep chip state mirrored without double-calling user callback:
				handle.State = v and true or handle.State
			end)
		end

		function handle:Get()
			return handle.Value and handle.Value.Name or "None"
		end
		function handle:Destroy()
			handle:_destroyConns()
			handle:_unregister()
			chip:Destroy()
		end

		return handle
	end

    return Keybind
end
