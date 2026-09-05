--[[==========================================================================]]
-- Tracium v2 · Components/Paragraph.lua
-- Title + multi-line body card, optional icon. :SetTitle / :SetContent / :Set(table)
--[[==========================================================================]]

return function(Shared)
	local Paragraph = {}
	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Icons = Shared.Icons

	function Paragraph.New(scope, opts)
		opts = opts or {}
		local root = Utility.New("Frame", {
			Name = "Paragraph",
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = scope.Index,
			Parent = scope.Page,
		})
		Utility.Paint(root, "BackgroundColor3", "Card")
		Utility.Round(root, 8)
		Utility.Stroke(root, "Stroke", 1, 0.6)
		Utility.Pad(root, 12, 10, 12, 10)

		local col = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = root,
		})
		Utility.ListLayout(col, { Padding = 4 })

		-- header (optional icon + title)
		local header = Utility.New("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = col,
		})
		Utility.ListLayout(header, { Direction = "Horizontal", Padding = 8, Vertical = "Center" })

		if opts.Icon then
			Icons:Create(opts.Icon, { Size = 16, Color = opts.IconColor or "Accent", Parent = header })
		end

		local title = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Theme:Get("Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, opts.Icon and -26 or 0, 0, 0),
			Text = opts.Title or "Info",
			TextWrapped = true,
			Parent = header,
		})
		Utility.Paint(title, "TextColor3", "Text")

		local content = Utility.New("TextLabel", {
			Name = "Content",
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Theme:Get("SubText"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			RichText = opts.RichText == true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Text = opts.Content or "",
			Parent = col,
		})
		Utility.Paint(content, "TextColor3", "SubText")
		content.Visible = (opts.Content or "") ~= ""

		local self = {
			Type = "Paragraph",
			Root = root,
			Options = opts,
			Value = { Title = opts.Title, Content = opts.Content },
		}

		function self:SetTitle(t)
			title.Text = tostring(t)
		end

		function self:SetContent(c)
			content.Text = tostring(c or "")
			content.Visible = content.Text ~= ""
		end

		function self:Set(opts2)
			opts2 = opts2 or {}
			if opts2.Title then
				self:SetTitle(opts2.Title)
			end
			if opts2.Content ~= nil then
				self:SetContent(opts2.Content)
			end
		end

		function self:Get()
			return { Title = title.Text, Content = content.Text }
		end

		function self:Destroy()
			root:Destroy()
		end

		return self
	end

	return Paragraph
end
