--[[==========================================================================]]
-- Tracium v2 · Components/Image.lua
-- Rounded image card (thumbnails, previews). Supports lucide icon fallback.
--
--   Section:Image({ Title="Map", Image="rbxassetid://123", Height=140 })
--[[==========================================================================]]

return function(Shared)
	local Image = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Icons = Shared.Icons

	function Image.New(scope, opts)
		opts = opts or {}
		local root = Utility.New("Frame", {
			Name = "Image",
			BackgroundColor3 = Theme:Get("Element"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			ClipsDescendants = true,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Element")
		Utility.Round(root, 10)
		Utility.Stroke(root, "Stroke", 1, 0.55)

		local holder = Utility.New("Frame", {
			Name = "Holder",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, opts.Height or 140),
			Parent = root,
		})

		local img = Utility.New("ImageLabel", {
			Name = "Img",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ScaleType = opts.ScaleType or Enum.ScaleType.Crop,
			Image = "",
			Parent = holder,
		})
		Utility.Round(img, 10)

		local function setImage(src)
			if type(src) ~= "string" or src == "" then
				img.Image = ""
				return
			end
			if src:match("^rbxasset") or src:match("://") then
				img.Image = src
			elseif Icons.Exists(src) then
				-- lucide icon fallback: centered icon instead of image fill
				img.Image = ""
				local ic = Icons:Create(src, {
					Size = 32, Color = "Muted",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Parent = holder,
					Name = "FallbackIcon",
				})
				ic.ZIndex = 2
			else
				img.Image = "rbxassetid://" .. src
			end
		end
		setImage(opts.Image or opts.Asset or opts.Icon)

		local title
		if opts.Title then
			title = Utility.New("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = Theme:Get("SubText"),
				TextXAlignment = Enum.TextXAlignment.Left,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				Text = opts.Title,
				Parent = root,
			})
			Utility.Paint(title, "TextColor3", "SubText")
			Utility.Pad(title, 4, 6, 0, 6)
			-- need container for padding to respect layout; simplest: put title below holder via list layout
			local layout = Utility.ListLayout(root, { Padding = 0 })
			holder.LayoutOrder = 1
			title.LayoutOrder = 2
			_ = layout
		end

		local self = {
			Type = "Image",
			Root = root,
			Options = opts,
			Value = opts.Image,
		}

		function self:Set(src)
			setImage(src)
			self.Value = src
		end
		function self:Get()
			return self.Value
		end
		function self:Destroy()
			root:Destroy()
		end

		return self
	end

	return Image
end
