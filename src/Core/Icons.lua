--[[==========================================================================]]
-- Tracium v2 · Core/Icons.lua
-- Lucide icon lookup + ImageLabel factory.
-- Icon data lives in Core/IconMap.lua (auto-generated, see tools/).
--
--   Icons.Get("home")        -> {id, w, h, ox, oy} or nil
--   Icons.Exists("home")     -> bool
--   Icons:Apply(imageLabel, "home")  -> ok
--   Icons:Create("home", {Size=16, Color=..., Parent=...}) -> ImageLabel
--[[==========================================================================]]

return function(Shared)
	local Icons = {}

	local Data = Shared.Load("Core.IconMap")

	-- Friendly aliases -> canonical lucide names
	local Aliases = {
		edit = "pencil", ["edit-2"] = "pen-line", ["edit-3"] = "square-pen",
		tool = "wrench", sidebar = "panel-left", grid = "grid-2x2",
		["alert"] = "alert-circle", warn = "alert-triangle", error = "alert-octagon",
		gear = "settings", cog2 = "settings-2", exit = "log-out", enter = "log-in",
		remove = "minus", add = "plus", close = "x", tick = "check",
		dot = "circle", colour = "palette", color = "palette",
		controllers = "gamepad-2", game = "gamepad-2", esp = "eye",
	}

	function Icons.Resolve(name)
		if type(name) ~= "string" then
			return nil
		end
		name = name:lower()
		return Aliases[name] or name
	end

	function Icons.Get(name)
		name = Icons.Resolve(name)
		if not name then
			return nil
		end
		return Data[name]
	end

	function Icons.Exists(name)
		return Icons.Get(name) ~= nil
	end

	function Icons.Names()
		local out = {}
		for k in pairs(Data) do
			table.insert(out, k)
		end
		table.sort(out)
		return out
	end

	-- Apply icon rendering properties to an existing ImageLabel/ImageButton.
	function Icons:Apply(imageLabel, name)
		local entry = Icons.Get(name)
		if not entry then
			-- unknown icon: render nothing (transparent) rather than an error
			imageLabel.Image = ""
			return false
		end
		imageLabel.Image = "rbxassetid://" .. tostring(entry[1])
		imageLabel.ImageRectSize = Vector2.new(entry[2], entry[3])
		imageLabel.ImageRectOffset = Vector2.new(entry[4], entry[5])
		imageLabel.ScaleType = Enum.ScaleType.Fit
		imageLabel.BackgroundTransparency = 1
		return true
	end

	-- Create a themed icon ImageLabel.
	-- Icons:Create(name, { Size = 16, Color = Color3|themeKey, Rotation, Parent, ZIndex,
	--                      ImageTransparency, AnchorPoint, Position, LayoutOrder, Name })
	function Icons:Create(name, opts)
		opts = opts or {}
		local size = opts.Size or 16
		local img = Shared.Utility.New("ImageLabel", {
			Name = opts.Name or ("Icon_" .. tostring(name)),
			AnchorPoint = opts.AnchorPoint or Vector2.new(0, 0),
			Position = opts.Position or UDim2.new(),
			Size = typeof(opts.Size) == "UDim2" and opts.Size or UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ImageTransparency = opts.ImageTransparency or 0,
			Rotation = opts.Rotation or 0,
			ZIndex = opts.ZIndex or 2,
			LayoutOrder = opts.LayoutOrder or 0,
			Parent = opts.Parent,
		})
		Icons:Apply(img, name)
		local color = opts.Color
		if color == nil then
			img.ImageColor3 = Shared.Theme:Get("Text")
		elseif type(color) == "string" then
			Shared.Utility.Paint(img, "ImageColor3", color)
		else
			img.ImageColor3 = color
		end
		return img
	end

	-- Convenience: small icon + themed text row, used inside buttons/labels.
	function Icons:IconText(name, text, opts)
		opts = opts or {}
		local row = Shared.Utility.New("Frame", {
			Name = "IconText",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, (opts.Size or 16) + 4),
			Parent = opts.Parent,
		})
		Shared.Utility.ListLayout(row, { Direction = "Horizontal", Padding = 6, Vertical = "Center" })
		Icons:Create(name, { Size = opts.Size or 16, Color = opts.IconColor or "SubText", Parent = row })
		if text and text ~= "" then
			local lab = Shared.Utility.New("TextLabel", {
				Name = "Label",
				BackgroundTransparency = 1,
				Font = opts.Font or Enum.Font.GothamMedium,
				Text = text,
				TextSize = opts.TextSize or 12,
				TextColor3 = Shared.Theme:Get(opts.TextColor or "SubText"),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				Parent = row,
			})
			Shared.Utility.Paint(lab, "TextColor3", opts.TextColor or "SubText")
		end
		return row
	end

	return Icons
end
