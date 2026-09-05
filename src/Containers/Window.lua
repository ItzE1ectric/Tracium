--[[==========================================================================]]
-- Tracium v2 · Containers/Window.lua
-- The window: topbar, sidebar (tabs + search + user card), content host,
-- popup/dialog layers, restore pill, drag/resize, global toggle key,
-- optional loading splash + key system + watermark + settings tab.
--[[==========================================================================]]

return function(Shared)
	local WindowClass = {}
	WindowClass.__index = WindowClass

	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween
	local Icons = Shared.Icons
	local Config = Shared.Config
	local Services = Shared.Services

	----------------------------------------------------------------------
	-- Construction
	----------------------------------------------------------------------

	function WindowClass.New(shared, opts)
		opts = opts or {}
		local Self = setmetatable({}, WindowClass)

		Self.Options = opts
		Self.Title = opts.Title or "Tracium"
		Self.Subtitle = opts.Subtitle or ""
		Self.Tabs = {}
		Self.TabOrder = {}
		Self.SelectedTab = nil
		Self.Flags = Shared.Library.Flags
		Self.Open = true
		Self._elements = {}
		Self._popups = {}
		Self._maid = Utility.Maid()
		Self._toggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
		if type(Self._toggleKey) == "string" then
			Self._toggleKey = Utility.KeyFromName(Self._toggleKey) or Enum.KeyCode.RightShift
		end

		Config.Folder = opts.ConfigFolder or opts.FolderName or "Tracium"

		-- -- screen gui ---------------------------------------------------
		local gui = Utility.New("ScreenGui", {
			Name = "TraciumWin_" .. Utility.UID(),
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = 900,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
		Utility.ProtectGui(gui)
		Self.Gui = gui

		-- -- acrylic ------------------------------------------------------
		Self._acrylicAttached = false
		if opts.Acrylic ~= false then
			Self._acrylicAttached = Shared.Acrylic:Attach()
		end

		-- -- window frame --------------------------------------------------
		local size = opts.Size or UDim2.fromOffset(720, 540)
		if typeof(size) == "Vector2" then
			size = UDim2.fromOffset(size.X, size.Y)
		end
		Self.Size = size

		local root = Utility.New("Frame", {
			Name = "Root",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = size,
			BackgroundColor3 = Theme:Get("Background"),
			BackgroundTransparency = (opts.Acrylic ~= false and Self._acrylicAttached) and 0.05 or 0,
			ClipsDescendants = true,
			Parent = gui,
		})
		Utility.Paint(root, "BackgroundColor3", "Background")
		Utility.Round(root, 14)
		Utility.Stroke(root, "Stroke", 1, 0.35)
		Self.Root = root

		-- layered soft shadows
		for i, t in ipairs({ 0.82, 0.68, 0.55 }) do
			local sh = Utility.New("Frame", {
				Name = "Shadow" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 22 + i * 16, 1, 22 + i * 16),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = t,
				ZIndex = -i,
				Parent = root,
			})
			Utility.Round(sh, 20 + i * 3)
		end

		-- size constraints + global ui scale
		local minSize = opts.MinSize or UDim2.fromOffset(480, 360)
		Utility.New("UISizeConstraint", {
			MinSize = Vector2.new(minSize.X.Offset, minSize.Y.Offset),
			Parent = root,
		})
		Self._scale = Utility.New("UIScale", { Scale = opts.UIScale or 1, Parent = root })

		-- intro animation
		Self._scale.Scale = (opts.UIScale or 1) * 0.94
		Tween:Play(Self._scale, "Spring", { Scale = opts.UIScale or 1 })

		-- loading splash (optional): dims the window content until done
		if opts.LoadingEnabled then
			local splash = Utility.New("Frame", {
				Name = "LoadingSplash",
				BackgroundColor3 = Theme:Get("Background"),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 90,
				Visible = true,
				Parent = root,
			})
			Utility.Paint(splash, "BackgroundColor3", "Background")

			local spinner = Icons:Create("loader", {
				Name = "Spinner", Size = 34, Color = "Accent",
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Parent = splash,
			})
			local stopSpin = Tween:Spin(spinner, 1.1)

			local lt = Utility.New("TextLabel", {
				BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16,
				TextColor3 = Theme:Get("Text"), Text = opts.LoadingTitle or Self.Title,
				Position = UDim2.new(0, 0, 0, 84), Size = UDim2.new(1, 0, 0, 20), ZIndex = 91,
				Parent = splash,
			})
			Utility.Paint(lt, "TextColor3", "Text")
			local ls = Utility.New("TextLabel", {
				BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
				TextColor3 = Theme:Get("SubText"), Text = opts.LoadingSubtitle or "loading modules...",
				Position = UDim2.new(0, 0, 0, 108), Size = UDim2.new(1, 0, 0, 16), ZIndex = 91,
				Parent = splash,
			})
			Utility.Paint(ls, "TextColor3", "SubText")

			task.delay(1.2, function()
				if not splash.Parent then
					return
				end
				stopSpin()
				Tween:Play(splash, "Fade", { GroupTransparency = 1 })
				-- GroupTransparency only exists on CanvasGroup; fade via children instead
				Tween:Play(spinner, "Fast", { ImageTransparency = 1 })
				Tween:Play(lt, "Fast", { TextTransparency = 1 })
				Tween:Play(ls, "Fast", { TextTransparency = 1 })
				Tween:Play(splash, "Fast", { BackgroundTransparency = 1 })
				task.delay(0.3, function()
					if splash.Parent then
						splash:Destroy()
					end
				end)
			end)
		end

		-- key system (optional hard gate)
		if opts.KeySystem and type(opts.KeySystem) == "table" and opts.KeySystem.Enabled ~= false then
			local ks = opts.KeySystem
			local gate = Utility.New("Frame", {
				Name = "KeySystem",
				BackgroundColor3 = Theme:Get("Background"),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 95,
				Visible = true,
				Parent = root,
			})
			Utility.Paint(gate, "BackgroundColor3", "Background")

			local panel = Utility.New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, 300, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme:Get("Surface"),
				ZIndex = 96,
				Parent = gate,
			})
			Utility.Paint(panel, "BackgroundColor3", "Surface")
			Utility.Round(panel, 12)
			Utility.Stroke(panel, "StrokeHover", 1, 0.35)
			Utility.Pad(panel, 18, 16, 18, 16)

			local plist = Utility.New("Frame", {
				BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0), Parent = panel,
			})
			Utility.ListLayout(plist, { Padding = 8 })

			Utility.New("TextLabel", {
				BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 15,
				TextColor3 = Theme:Get("Text"), Text = ks.Title or (Self.Title .. " — Key Required"),
				Size = UDim2.new(1, 0, 0, 20), ZIndex = 97, Parent = plist,
			})

			if ks.Subtitle and ks.Subtitle ~= "" then
				Utility.New("TextLabel", {
					BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
					TextColor3 = Theme:Get("SubText"), TextWrapped = true,
					Text = ks.Subtitle, AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 0), ZIndex = 97, Parent = plist,
				})
			end

			local keyField = Utility.New("Frame", {
				BackgroundColor3 = Theme:Get("Input"), Size = UDim2.new(1, 0, 0, 32), ZIndex = 97, Parent = plist,
			})
			Utility.Paint(keyField, "BackgroundColor3", "Input")
			Utility.Round(keyField, 8)
			local keyBox = Utility.New("TextBox", {
				BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13,
				TextColor3 = Theme:Get("Text"), PlaceholderText = ks.Placeholder or "enter key...",
				PlaceholderColor3 = Theme:Get("Muted"), Text = "",
				Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0),
				ClearTextOnFocus = false, ZIndex = 98, Parent = keyField,
			})
			Utility.Paint(keyBox, "TextColor3", "Text")
			Utility.Paint(keyBox, "PlaceholderColor3", "Muted")

			local getKeyBtn
			if ks.GetKeyLabel and ks.GetKeyURL then
				getKeyBtn = Utility.New("TextButton", {
					BackgroundColor3 = Theme:Get("Card"), Font = Enum.Font.GothamMedium, TextSize = 11,
					TextColor3 = Theme:Get("SubText"), Text = ks.GetKeyLabel, AutoButtonColor = false,
					Size = UDim2.new(1, 0, 0, 24), ZIndex = 97, Parent = plist,
				})
				Utility.Paint(getKeyBtn, "BackgroundColor3", "Card")
				Utility.Round(getKeyBtn, 7)
				getKeyBtn.MouseButton1Click:Connect(function()
					if setclipboard then
						pcall(setclipboard, tostring(ks.GetKeyURL))
					end
					Shared.Notify:Notify({ Title = "Key link copied", Content = tostring(ks.GetKeyURL), Duration = 3 })
				end)
			end

			local submitBtn = Utility.New("TextButton", {
				BackgroundColor3 = Theme:Get("Accent"), Font = Enum.Font.GothamBold, TextSize = 13,
				TextColor3 = Theme:Get("AccentText"), Text = ks.SubmitLabel or "Unlock",
				AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 30), ZIndex = 97, Parent = plist,
			})
			Utility.Paint(submitBtn, "BackgroundColor3", "Accent")
			Utility.Paint(submitBtn, "TextColor3", "AccentText")
			Utility.Round(submitBtn, 8)

			local statusLab = Utility.New("TextLabel", {
				BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
				TextColor3 = Theme:Get("Danger"), Text = "", Size = UDim2.new(1, 0, 0, 14),
				ZIndex = 97, Visible = false, Parent = plist,
			})

			local function checkKey()
				if ks.Validate then
					local ok, res = pcall(ks.Validate, keyBox.Text)
					return ok and res == true
				end
				for _, k in ipairs(ks.Keys or {}) do
					if tostring(k) == keyBox.Text then
						return true
					end
				end
				return false
			end

			local function tryUnlock()
				if checkKey() then
					statusLab.Visible = false
					Tween:Play(gate, "Fade", { BackgroundTransparency = 1 })
					Tween:Play(panel, "Fade", { BackgroundTransparency = 1 })
					task.delay(0.25, function()
						if gate.Parent then gate:Destroy() end
					end)
					Shared.Notify:Notify({ Title = "Access granted", Content = "Welcome back.", Type = "Success", Duration = 2 })
				else
					statusLab.Text = ks.FailMessage or "Invalid key"
					statusLab.Visible = true
					Tween:Play(panel, "Fast", { Position = UDim2.fromScale(0.5, 0.502) })
					task.delay(0.05, function()
						Tween:Play(panel, "Fast", { Position = UDim2.fromScale(0.5, 0.5) })
					end)
				end
			end
			submitBtn.MouseButton1Click:Connect(tryUnlock)
			keyBox.FocusLost:Connect(function(enter)
				if enter then tryUnlock() end
			end)
		end

		----------------------------------------------------------------
		-- Topbar
		----------------------------------------------------------------
		local topbar = Utility.New("Frame", {
			Name = "Topbar",
			BackgroundColor3 = Theme:Get("Surface"),
			BackgroundTransparency = 0.15,
			Size = UDim2.new(1, 0, 0, 46),
			Parent = root,
		})
		Utility.Paint(topbar, "BackgroundColor3", "Surface")

		Utility.New("Frame", { -- accent underline
			Name = "AccentLine",
			BackgroundColor3 = Theme:Get("Accent"),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			Parent = topbar,
		})

		-- logo
		local logo = Utility.New("Frame", {
			Name = "Logo",
			BackgroundColor3 = Theme:Get("Accent"),
			Position = UDim2.new(0, 14, 0.5, -13),
			Size = UDim2.fromOffset(26, 26),
			Parent = topbar,
		})
		Utility.Round(logo, 7)
		Utility.Gradient(logo, "Accent", "Accent2", 135)
		Icons:Create(opts.Icon or "zap", {
			Size = 15, Color = Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = logo,
		})

		local titleLabel = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 48, 0, 6),
			Size = UDim2.new(1, -240, 0, 18),
			Text = Self.Title,
			Parent = topbar,
		})
		Utility.Paint(titleLabel, "TextColor3", "Text")

		local subLabel = Utility.New("TextLabel", {
			Name = "Subtitle",
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextColor3 = Theme:Get("SubText"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 48, 0, 24),
			Size = UDim2.new(1, -240, 0, 14),
			Text = Self.Subtitle,
			Parent = topbar,
		})
		Utility.Paint(subLabel, "TextColor3", "SubText")

		-- tag chip
		local function endChip(text, xOffset, tooltipText)
			local chip = Utility.New("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, xOffset, 0.5, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 0, 20),
				BackgroundColor3 = Theme:Get("Card"),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextColor3 = Theme:Get("Accent"),
				Text = "  " .. text .. "  ",
				Parent = topbar,
			})
			Utility.Paint(chip, "BackgroundColor3", "Card")
			Utility.Paint(chip, "TextColor3", "Accent")
			Utility.Round(chip, 6)
			Utility.Stroke(chip, "Accent", 1, 0.6)
			if tooltipText then
				Shared.Tooltip:Attach(chip, tooltipText)
			end
			return chip
		end

		local rightOffset = -50
		if opts.Tag then
			endChip(opts.Tag, rightOffset)
			rightOffset -= 90
		end

		-- close + minimize icon buttons
		local function topIcon(iconName, xOffset, tint)
			local btn = Utility.New("TextButton", {
				Name = "TopBtn_" .. iconName,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, xOffset, 0.5, 0),
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = Theme:Get("Card"),
				BackgroundTransparency = 0.4,
				Text = "",
				AutoButtonColor = false,
				Parent = topbar,
			})
			Utility.Round(btn, 6)
			local img = Icons:Create(iconName, {
				Size = 12, Color = tint or "SubText",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Parent = btn,
			})
			btn.MouseEnter:Connect(function()
				Tween:Play(btn, "Fast", { BackgroundTransparency = 0 })
				Tween:Play(img, "Fast", { ImageColor3 = Theme:Get("Text") })
			end)
			btn.MouseLeave:Connect(function()
				Tween:Play(btn, "Fast", { BackgroundTransparency = 0.4 })
				Tween:Play(img, "Fast", { ImageColor3 = Theme:Get(tint or "SubText") })
			end)
			return btn
		end

		local closeBtn = topIcon("x", -12, "Danger")
		local minBtn = topIcon("minus", -40)

		closeBtn.MouseButton1Click:Connect(function()
			Self:Destroy()
		end)

		----------------------------------------------------------------
		-- Sidebar
		----------------------------------------------------------------
		local SIDE_W = 186

		local sidebar = Utility.New("Frame", {
			Name = "Sidebar",
			BackgroundColor3 = Theme:Get("Sidebar"),
			BackgroundTransparency = 0.05,
			Position = UDim2.new(0, 0, 0, 47),
			Size = UDim2.new(0, SIDE_W, 1, -47),
			Parent = root,
		})
		Utility.Paint(sidebar, "BackgroundColor3", "Sidebar")

		Utility.New("Frame", { -- right divider
			BackgroundColor3 = Theme:Get("Divider"),
			BorderSizePixel = 0,
			Position = UDim2.new(1, -1, 0, 0),
			Size = UDim2.new(0, 1, 1, 0),
			Parent = sidebar,
		})

		-- search
		local searchEnabled = opts.Search ~= false
		local searchWrap
		if searchEnabled then
			searchWrap = Utility.New("Frame", {
				Name = "Search",
				BackgroundColor3 = Theme:Get("Input"),
				Position = UDim2.new(0, 10, 0, 10),
				Size = UDim2.new(1, -20, 0, 30),
				Parent = sidebar,
			})
			Utility.Paint(searchWrap, "BackgroundColor3", "Input")
			Utility.Round(searchWrap, 8)
			Utility.Stroke(searchWrap, "Stroke", 1, 0.55)

			Icons:Create("search", {
				Size = 13, Color = "Muted",
				Position = UDim2.new(0, 9, 0.5, -6),
				Parent = searchWrap,
			})

			local box = Utility.New("TextBox", {
				Name = "Box",
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextColor3 = Theme:Get("Text"),
				PlaceholderText = "Search settings...",
				PlaceholderColor3 = Theme:Get("Muted"),
				Text = "",
				ClearTextOnFocus = false,
				Position = UDim2.new(0, 30, 0, 0),
				Size = UDim2.new(1, -36, 1, 0),
				Parent = searchWrap,
			})
			Utility.Paint(box, "TextColor3", "Text")
			Utility.Paint(box, "PlaceholderColor3", "Muted")
			Self._searchBox = box
		end

		-- tab list
		local tabList = Utility.New("ScrollingFrame", {
			Name = "Tabs",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 8, 0, searchEnabled and 50 or 12),
			Size = UDim2.new(1, -16, 1, searchEnabled and -110 or -70),
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Theme:Get("Muted"),
			Parent = sidebar,
		})
		Utility.Paint(tabList, "ScrollBarImageColor3", "Muted")
		local tabLayout = Utility.ListLayout(tabList, { Padding = 4 })
		Utility.ConnectCanvas(tabList, tabLayout, 4)

		-- user card
		if opts.UserInfo ~= false then
			local card = Utility.New("Frame", {
				Name = "User",
				BackgroundColor3 = Theme:Get("Card"),
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 10, 1, -10),
				Size = UDim2.new(1, -20, 0, 46),
				Parent = sidebar,
			})
			Utility.Paint(card, "BackgroundColor3", "Card")
			Utility.Round(card, 10)
			Utility.Stroke(card, "Stroke", 1, 0.55)

			local avatar = Utility.New("ImageLabel", {
				Name = "Avatar",
				BackgroundColor3 = Theme:Get("Element"),
				Position = UDim2.new(0, 8, 0.5, -15),
				Size = UDim2.fromOffset(30, 30),
				Parent = card,
			})
			Utility.Round(avatar, 15)
			Utility.Stroke(avatar, "Accent", 1.5, 0.4)
			task.spawn(function()
				local lp = Services.LocalPlayer
				if lp then
					local ok, thumb = pcall(function()
						return Services.Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
					end)
					if ok and thumb then
						avatar.Image = thumb
					end
				end
			end)

			local info = opts.UserInfo
			local displayName = type(info) == "table" and info.Name
				or (Services.LocalPlayer and (Services.LocalPlayer.DisplayName or Services.LocalPlayer.Name) or "Player")
			local nameLab = Utility.New("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = Theme:Get("Text"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.new(0, 46, 0, 8),
				Size = UDim2.new(1, -52, 0, 15),
				Text = displayName,
				Parent = card,
			})
			Utility.Paint(nameLab, "TextColor3", "Text")

			local subTxt = type(info) == "table" and info.SubTitle
				or (Services.LocalPlayer and ("@" .. Services.LocalPlayer.Name)) or ""
			local subLab = Utility.New("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 10,
				TextColor3 = Theme:Get("Muted"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.new(0, 46, 0, 24),
				Size = UDim2.new(1, -52, 0, 13),
				Text = subTxt,
				Parent = card,
			})
			Utility.Paint(subLab, "TextColor3", "Muted")
		end

		-- brand footer
		Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 9,
			TextColor3 = Theme:Get("Muted"),
			Text = "TRACIUM v" .. Shared.Version,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -4 - (opts.UserInfo ~= false and 48 or 0)),
			Size = UDim2.new(1, -24, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = sidebar,
			Name = "Brand",
		})

		----------------------------------------------------------------
		-- Content host
		----------------------------------------------------------------
		local contentHost = Utility.New("Frame", {
			Name = "Content",
			BackgroundColor3 = Theme:Get("Inset"),
			BackgroundTransparency = 0.35,
			Position = UDim2.new(0, SIDE_W, 0, 47),
			Size = UDim2.new(1, -SIDE_W, 1, -47),
			Parent = root,
		})
		Utility.Paint(contentHost, "BackgroundColor3", "Inset")
		Self._contentHost = contentHost

		----------------------------------------------------------------
		-- Popup layer + click catcher
		----------------------------------------------------------------
		local popupLayer = Utility.New("Frame", {
			Name = "PopupLayer",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 40,
			Parent = root,
		})

		local catcher = Utility.New("TextButton", {
			Name = "Catcher",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 39,
			AutoButtonColor = false,
			Parent = popupLayer,
		})
		catcher.MouseButton1Click:Connect(function()
			Self:ClosePopups()
		end)
		Self.PopupLayer = popupLayer

		-- dialog overlay origin
		local dialogHost = Utility.New("Frame", {
			Name = "DialogHost",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = true,
			ZIndex = 50,
			Parent = root,
		})
		Self.DialogHost = dialogHost

		function Self:OpenPopupHandle(frame, closeFn)
			popupLayer.Visible = true
			frame.Parent = popupLayer
			self._popups[frame] = closeFn or true
		end

		function Self:ClosePopups()
			for frame, closeFn in pairs(self._popups) do
				if type(closeFn) == "function" then
					pcall(closeFn)
				end
				if frame and frame.Parent then
					frame.Parent = nil
				end
			end
			table.clear(self._popups)
			popupLayer.Visible = false
		end

		----------------------------------------------------------------
		-- Dragging + resize
		----------------------------------------------------------------
		Self._maid:Give(Shared.Drag:MakeDraggable(topbar, root, {
			Bounds = true,
			Lerp = 0.35,
		}))

		if opts.Resizable ~= false then
			local grip = Utility.New("TextButton", {
				Name = "ResizeGrip",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -2, 1, -2),
				Size = UDim2.fromOffset(18, 18),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 46,
				Parent = root,
			})
			local gripIcon = Icons:Create("resize-bottom-right", {
				Size = 12, Color = "Muted",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Parent = grip,
			})
			if not Icons.Exists("resize-bottom-right") then
				Icons:Apply(gripIcon, "maximize-2")
				gripIcon.Rotation = 90
			end
			local resizing = false
			local startSize, startInput
			grip.InputBegan:Connect(function(input)
				if Utility.IsClick(input) then
					resizing = true
					startSize = root.Size
					startInput = input.Position
				end
			end)
			Self._maid:Give(Services.UserInputService.InputChanged:Connect(function(input)
				if resizing and Utility.IsMove(input) then
					local delta = Vector2.new(input.Position.X - startInput.X, input.Position.Y - startInput.Y)
					root.Size = UDim2.new(0, math.max(startSize.X.Offset + delta.X, 480), 0, math.max(startSize.Y.Offset + delta.Y, 340))
				end
			end))
			Self._maid:Give(Services.UserInputService.InputEnded:Connect(function(input)
				if Utility.IsClick(input) then
					resizing = false
				end
			end))
		end

		----------------------------------------------------------------
		-- Toggle key + restore pill
		----------------------------------------------------------------
		local pill = Utility.New("TextButton", {
			Name = "RestorePill",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 16, 1, -16),
			Size = UDim2.new(0, 160, 0, 38),
			BackgroundColor3 = Theme:Get("Surface"),
			Visible = false,
			Text = "",
			AutoButtonColor = false,
			Parent = gui,
		})
		Utility.Paint(pill, "BackgroundColor3", "Surface")
		Utility.Round(pill, 12)
		Utility.Stroke(pill, "Accent", 1.5, 0.3)
		Utility.Pad(pill, 10, 0, 10, 0)

		local pillDot = Utility.New("Frame", {
			BackgroundColor3 = Theme:Get("Accent"),
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new(0, 6, 0.5, -7),
			Parent = pill,
		})
		Utility.Round(pillDot, 7)
		Utility.Gradient(pillDot, "Accent", "Accent2", 135)

		Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Theme:Get("Text"),
			Text = Self.Title,
			Position = UDim2.new(0, 28, 0, 0),
			Size = UDim2.new(1, -28, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = pill,
		})
		Self._pill = pill

		Shared.Drag:MakeDraggable(pill, pill, { Lerp = 0.45 })
		pill.MouseButton1Click:Connect(function()
			Self:Show()
		end)

		Self._maid:Give(Services.UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe or Utility.IsTyping() then
				return
			end
			if Self._toggleKey and input.KeyCode == Self._toggleKey then
				Self:Toggle()
			end
		end))

		----------------------------------------------------------------
		-- Watermark
		----------------------------------------------------------------
		if opts.Watermark and opts.Watermark.Enabled ~= false then
			Self:_createWatermark(opts.Watermark)
		end

		----------------------------------------------------------------
		-- Tab registry + helpers
		----------------------------------------------------------------
		Self._tabList = tabList
		Self._sidebar = sidebar

		-- register element for cross-tab search
		function Self:_registerElement(element, searchText, section)
			table.insert(Self._elements, {
				Element = element,
				Search = (searchText or ""):lower(),
				Section = section,
				Tab = section and section._tab,
			})
		end

		-- search filtering (hides/shows elements & dims tabs without matches)
		if searchEnabled then
			local searchBox = Self._searchBox
			local function applyFilter(q)
				q = (q or ""):lower()
				local tabHasMatch = {}
				for _, entry in ipairs(Self._elements) do
					local match = q == "" or entry.Search:find(q, 1, true) ~= nil
					if entry.Element and entry.Element.Root and entry.Element.Root.Parent then
						entry.Element.Root.Visible = match
					end
					if match and entry.Tab then
						tabHasMatch[entry.Tab._name] = true
					end
				end
				-- dim tabs with zero matches
				for _, tab in ipairs(Self.TabOrder) do
					local btn = tab._button
					if btn then
						local dimmed = q ~= "" and not tabHasMatch[tab._name]
						Tween:Play(btn, "Fast", { TextTransparency = dimmed and 0.6 or 0 })
					end
				end
				-- jump to first matching tab
				if q ~= "" and Self.SelectedTab and not tabHasMatch[Self.SelectedTab._name] then
					for _, tab in ipairs(Self.TabOrder) do
						if tabHasMatch[tab._name] then
							Self:SelectTab(tab._name)
							break
						end
					end
				end
			end
			searchBox:GetPropertyChangedSignal("Text"):Connect(function()
				applyFilter(searchBox.Text)
			end)
			Self._applyFilter = applyFilter
		end

		----------------------------------------------------------------
		-- Tabs
		----------------------------------------------------------------
		local tabButtons = {}

		function Self:Tab(name, iconName)
			if type(name) == "table" then
				iconName = name.Icon or name.Image
				name = name.Title or name.Name
			end
			name = tostring(name or "Tab")

			local tab = Shared.Containers.Tab.New(Self, name, iconName)

			-- sidebar button
			local btn = Utility.New("TextButton", {
				Name = "TabBtn_" .. name,
				BackgroundColor3 = Theme:Get("Sidebar"),
				Size = UDim2.new(1, 0, 0, 32),
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = #Self.TabOrder + 1,
				Parent = Self._tabList,
			})
			Utility.Round(btn, 8)

			local indicator = Utility.New("Frame", {
				Name = "Indicator",
				BackgroundColor3 = Theme:Get("Accent"),
				Position = UDim2.new(0, 0, 0.25, 0),
				Size = UDim2.new(0, 3, 0.5, 0),
				BackgroundTransparency = 1,
				Parent = btn,
			})
			Utility.Round(indicator, 2)

			if iconName then
				Icons:Create(iconName, {
					Size = 14, Color = "SubText",
					Position = UDim2.new(0, 12, 0.5, -7),
					Parent = btn, Name = "Icon",
				})
			end

			local label = Utility.New("TextLabel", {
				Name = "Label",
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = Theme:Get("SubText"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.new(0, iconName and 34 or 14, 0, 0),
				Size = UDim2.new(1, iconName and -40 or -20, 1, 0),
				Text = name,
				Parent = btn,
			})

			btn.MouseButton1Click:Connect(function()
				Self:SelectTab(name)
			end)
			btn.MouseEnter:Connect(function()
				if Self.SelectedTab ~= tab then
					Tween:Play(btn, "Fast", { BackgroundColor3 = Theme:Get("Card") })
				end
			end)
			btn.MouseLeave:Connect(function()
				if Self.SelectedTab ~= tab then
					Tween:Play(btn, "Fast", { BackgroundColor3 = Theme:Get("Sidebar") })
				end
			end)

			tab._button = btn
			tab._btnLabel = label
			tab._btnIcon = btn:FindFirstChild("Icon")
			tab._btnIndicator = indicator
			tabButtons[name] = tab

			table.insert(Self.Tabs, tab)
			table.insert(Self.TabOrder, tab)

			if #Self.TabOrder == 1 then
				Self:SelectTab(name)
			end
			return tab
		end
		Self.CreateTab = Self.Tab

		function Self:SelectTab(nameOrIndex)
			local target
			if type(nameOrIndex) == "number" then
				target = Self.TabOrder[nameOrIndex]
			else
				target = tabButtons[nameOrIndex]
			end
			if not target then
				return
			end

			for _, tab in ipairs(Self.TabOrder) do
				local active = tab == target
				tab._page.Visible = active
				if active then
					tab._page.Position = UDim2.new(0, 0, 0, 6)
					Tween:Play(tab._page, "TabSwitch", { Position = UDim2.new(0, 0, 0, 0) })
				end
				if tab._button then
					Tween:Play(tab._button, "Fast", {
						BackgroundColor3 = active and Theme:Get("Card") or Theme:Get("Sidebar"),
					})
					if tab._btnLabel then
						Tween:Play(tab._btnLabel, "Fast", {
							TextColor3 = active and Theme:Get("Text") or Theme:Get("SubText"),
						})
					end
					if tab._btnIcon then
						Tween:Play(tab._btnIcon, "Fast", {
							ImageColor3 = active and Theme:Get("Accent") or Theme:Get("SubText"),
						})
					end
					if tab._btnIndicator then
						Tween:Play(tab._btnIndicator, "Fast", {
							BackgroundTransparency = active and 0 or 1,
						})
					end
				end
			end

			Self.SelectedTab = target
			Self:ClosePopups()
			if Self._applyFilter and Self._searchBox and Self._searchBox.Text ~= "" then
				Self._applyFilter(Self._searchBox.Text)
			end
		end

		----------------------------------------------------------------
		-- Private helpers (defined on the class below so methods work
		-- even for the first-created window)
		----------------------------------------------------------------

		-- open state
		function Self:Show()
			if Self.Open then return end
			Self.Open = true
			root.Visible = true
			pill.Visible = false
			Self._scale.Scale = (opts.UIScale or 1) * 0.95
			Tween:Play(Self._scale, "Spring", { Scale = opts.UIScale or 1 })
			if Self._acrylicAttached then
				Shared.Acrylic:SetEnabled(true)
			end
			for _, cb in ipairs(Self._onShow) do task.spawn(cb) end
		end

		function Self:Hide()
			if not Self.Open then return end
			Self.Open = false
			Self:ClosePopups()
			Tween:Play(Self._scale, "Fast", { Scale = (opts.UIScale or 1) * 0.96 })
			task.delay(0.12, function()
				root.Visible = false
				pill.Visible = true
			end)
			-- tab button hover fix
			if Self._acrylicAttached then
				Shared.Acrylic:SetEnabled(false)
			end
			for _, cb in ipairs(Self._onHide) do task.spawn(cb) end
		end

		function Self:Toggle()
			if Self.Open then
				Self:Hide()
			else
				Self:Show()
			end
		end

		Self._onShow, Self._onHide = {}, {}
		function Self:OnShow(fn) table.insert(Self._onShow, fn) end
		function Self:OnHide(fn) table.insert(Self._onHide, fn) end

		function Self:Minimize()
			Self:Hide()
		end

		-- center in viewport
		function Self:Center()
			local cam = Services.Workspace.CurrentCamera
			if cam then
				root.AnchorPoint = Vector2.new(0.5, 0.5)
				root.Position = UDim2.fromScale(0.5, 0.5)
			end
		end

		-- config passthrough
		function Self:Save() Config:Save() end
		function Self:SaveAs(name) Config:Save(name) end
		function Self:Load() Config:Load() end
		function Self:DeleteConfig(name) Config:Delete(name) end
		function Self:ConfigList() return Config:List() end

		function Self:Notify(nopts)
			return Shared.Notify:Notify(nopts)
		end

		function Self:SetTheme(name)
			return Theme:Set(name)
		end

		function Self:GetTheme()
			return Theme.Current
		end

		function Self:SetTitle(text)
			Self.Title = tostring(text)
			local tl = Self.Root and Self.Root:FindFirstChild("Topbar") and Self.Root.Topbar:FindFirstChild("Title")
			if tl then
				tl.Text = Self.Title
			end
		end

		function Self:Dialog(dopts)
			return Shared.Components.Dialog.Open(Self, dopts)
		end

		-- destroy everything
		function Self:Destroy()
			if not Self.Gui or not Self.Gui.Parent then return end
			Self:ClosePopups()
			for _, tab in ipairs(Self.TabOrder) do
				tab:Destroy()
			end
			Self._maid:Clean()
			if Self._watermarkConn then Self._watermarkConn:Disconnect() end
			if Self._watermark then Self._watermark:Destroy() end
			if Self._acrylicAttached then Shared.Acrylic:Release() end
			Tween:Play(Self._scale, "Fast", { Scale = (opts.UIScale or 1) * 0.92 })
			task.delay(0.15, function()
				if Self.Gui then Self.Gui:Destroy() end
			end)
			for i, w in ipairs(Shared.Library.Windows) do
				if w == Self then table.remove(Shared.Library.Windows, i) break end
			end
		end

		-- first-run config autoload
		if opts.ConfigName then
			Config.ActiveProfile = Config.SanitizeName(opts.ConfigName)
		end
		if opts.AutoLoadConfig ~= false and Config.ActiveProfile then
			Config:Load(Config.ActiveProfile)
		else
			local auto = Config:GetAutoload()
			if auto then
				Config:Load(auto)
			end
		end

		-- auto settings tab
		if opts.SettingsTab ~= false or opts.SettingsTab == nil then
			Self:CreateSettingsTab()
		end

		Shared.Notify:Notify({
			Title = Self.Title,
			Content = ("Loaded · Tracium v%s"):format(Shared.Version),
			Type = "Info",
			Duration = 3,
		})

		return Self
	end

	----------------------------------------------------------------------
	-- Watermark (draggable top-center FPS/Ping/Time pill)
	----------------------------------------------------------------------
	function WindowClass:_createWatermark(wopts)
		wopts = wopts or {}
		local showFPS = wopts.ShowFPS ~= false
		local showPing = wopts.ShowPing ~= false
		local showTime = wopts.ShowTime ~= false

		local wm = Utility.New("TextButton", {
			Name = "TraciumWatermark",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.new(0, 240, 0, 26),
			BackgroundColor3 = Theme:Get("Surface"),
			BackgroundTransparency = 0.06,
			Text = "",
			AutoButtonColor = false,
			Parent = Self.Gui,
		})
		Utility.Round(wm, 13)
		Utility.Stroke(wm, "Stroke", 1, 0.45)
		Utility.Paint(wm, "BackgroundColor3", "Surface")

		local label = Utility.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Theme:Get("Text"),
			Size = UDim2.fromScale(1, 1),
			Text = "TRACIUM",
			Parent = wm,
		})
		Utility.Paint(label, "TextColor3", "Text")

		Shared.Drag:MakeDraggable(wm, wm, { Lerp = 0.5 })

		local lastDt = 1 / 60
		local fps = 60
		local conn = Services.RunService.RenderStepped:Connect(function(dt)
			lastDt = dt
		end)
		Self._watermarkConn = conn

		task.spawn(function()
			while wm.Parent do
				fps = math.floor(1 / math.max(lastDt, 1e-5) + 0.5)
				local parts = { "TRACIUM" }
				if showFPS then
					table.insert(parts, fps .. " fps")
				end
				if showPing then
					local ok, ping = pcall(function()
						return math.floor(Services.Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
					end)
					if ok and ping then
						table.insert(parts, ping .. " ms")
					end
				end
				if showTime then
					table.insert(parts, os.date("%H:%M:%S"))
				end
				label.Text = table.concat(parts, "  ·  ")
				task.wait(0.5)
			end
		end)

		Self._watermark = wm
		return wm
	end

	function WindowClass:SetWatermarkVisible(v)
		if Self == nil then
			return
		end
	end

	function WindowClass:WatermarkVisible(v)
		if self._watermark then
			self._watermark.Visible = v and true or false
		end
	end

	----------------------------------------------------------------------
	-- Auto-generated Settings tab
	----------------------------------------------------------------------
	function WindowClass:CreateSettingsTab()
		local tab = self:Tab("Settings", "settings")

		local interface = tab:CreateSection("Interface", { Icon = "palette" })

		interface:Keybind({
			Title = "Menu key",
			Default = self._toggleKey,
			Flag = "__ui_togglekey",
			Tooltip = "Shows / hides the UI",
		})

		-- keep the live toggle key in sync with whatever the bind chip holds
		Shared.Config.Changed:Connect(function(flag, value)
			if flag == "__ui_togglekey" then
				self._toggleKey = Shared.Utility.KeyFromName(value) or self._toggleKey
			end
		end)

		interface:Dropdown({
			Title = "Theme",
			Values = Theme:Names(),
			Default = Theme.Current,
			Flag = "__ui_theme",
			Callback = function(name)
				Theme:Set(name)
			end,
			Tooltip = "Switch color palette",
			Searchable = true,
		})

		interface:Slider({
			Title = "UI scale",
			Min = 0.75, Max = 1.25, Default = 1, Increment = 0.05,
			Flag = "__ui_scale",
			Callback = function(v)
				self._scale.Scale = v
			end,
		})

		interface:Toggle({
			Title = "Acrylic blur",
			Default = self._acrylicAttached,
			Callback = function(v)
				if self._acrylicAttached then
					Shared.Acrylic:SetEnabled(v)
				end
			end,
		})

		interface:Dropdown({
			Title = "Notification position",
			Values = { "TopRight", "TopLeft", "BottomRight", "BottomLeft", "TopCenter", "BottomCenter" },
			Default = "TopRight",
			Callback = function(v)
				Shared.Notify:SetPosition(v)
			end,
		})

		interface:Toggle({
			Title = "Watermark",
			Default = self._watermark ~= nil,
			Callback = function(v)
				if self._watermark then
					self._watermark.Visible = v
				end
			end,
		})

		local configGroup = tab:CreateSection("Configuration", { Icon = "save" })
		if Shared.Addons and Shared.Addons.SaveManager then
			Shared.Addons.SaveManager:SetLibrary(Shared.Library):SetFolder(Config.Folder)
			Shared.Addons.SaveManager:ApplyToTab(configGroup)
		else
			configGroup:Button({ Title = "Save config", Callback = function()
				Config:Save()
				self:Notify({ Title = "Saved", Content = "Config written", Type = "Success", Duration = 2 })
			end })
			configGroup:Button({ Title = "Load config", Callback = function()
				Config:Load()
			end })
		end

		if Shared.Addons and Shared.Addons.ThemeManager then
			local themeGroup = tab:CreateSection("Custom Theme", { Icon = "droplet" })
			Shared.Addons.ThemeManager:SetLibrary(Shared.Library)
			Shared.Addons.ThemeManager:ApplyToTab(themeGroup)
		end

		local danger = tab:CreateSection("Danger Zone", { Icon = "alert-triangle" })
		danger:Button({
			Title = "Unload UI",
			Description = "Destroys the window and releases keybinds",
			Variant = "Danger",
			HoldToConfirm = true,
			Callback = function()
				self:Destroy()
			end,
		})

		danger:Label("Tracium v" .. Shared.Version)

		return tab
	end

	return WindowClass
end
