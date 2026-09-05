--[[==========================================================================]]
-- Tracium v2 · Containers/Section.lua
-- Section (full-width block with header) and GroupBox (bordered card used in
-- tab side-by-side columns). Both share the element factory that builds UI
-- components through Shared.Components.
--
-- Every element created through a Section/GroupBox is:
--   * parented into the section body
--   * registered for window search (Search attribute set by Window)
--   * the returned handle is the component handle (:Set/:Get/:Destroy...)
--[[==========================================================================]]

return function(Shared)
	local Section = {}
	local GroupBox = {}

	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Tween = Shared.Tween

	----------------------------------------------------------------------
	-- Shared element factory — mixed into Section and GroupBox objects.
	----------------------------------------------------------------------

	local ElementFactory = {}

	local function MakeScope(self, searchText)
		return {
			Window = self._window,
			Page = self._body or self._page,
			Index = (self._index or 0) + 1,
			Section = self,
			Search = searchText,
		}
	end

	local function Track(self, element, searchText)
		self._index = (self._index or 0) + 1
		table.insert(self._elements, element)
		if self._window and self._window._registerElement then
			self._window:_registerElement(element, searchText, self)
		end
		return element
	end

	function ElementFactory:Button(opts, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Callback = callback }
		end
		opts = opts or {}
		local el = Shared.Components.Button.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	-- Support both Toggle(state, callback) and Toggle(table)
	function ElementFactory:Toggle(opts, default, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Default = default, Callback = callback }
		end
		opts = opts or {}
		local el = Shared.Components.Toggle.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	function ElementFactory:Slider(opts, min, max, default, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Min = min, Max = max, Default = default, Callback = callback }
		end
		opts = opts or {}
		local el = Shared.Components.Slider.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	function ElementFactory:Dropdown(opts, values, default, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Values = values, Default = default, Callback = callback }
		end
		opts = opts or {}
		local el = Shared.Components.Dropdown.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	function ElementFactory:ColorPicker(opts, default, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Default = default, Callback = callback }
		end
		opts = opts or {}
		local el = Shared.Components.ColorPicker.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	function ElementFactory:Keybind(opts, default, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Default = default, Callback = callback }
		end
		opts = opts or {}
		local el = Shared.Components.Keybind.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	function ElementFactory:Input(opts, placeholder, callback)
		if type(opts) == "string" then
			opts = { Title = opts, Placeholder = placeholder, Callback = callback, EnterPressedOnly = false }
		end
		opts = opts or {}
		local el = Shared.Components.Input.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title .. " " .. (opts.Description or ""))
	end

	function ElementFactory:Label(opts, icon)
		if type(opts) == "string" then
			opts = { Title = opts, Icon = icon }
		end
		opts = opts or {}
		local el = Shared.Components.Label.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title or "")
	end

	function ElementFactory:Paragraph(title, content, icon)
		local opts
		if type(title) == "table" then
			opts = title
		else
			opts = { Title = title, Content = content, Icon = icon }
		end
		local el = Shared.Components.Paragraph.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, (opts.Title or "") .. " " .. (opts.Content or ""))
	end

	-- ``ol.Search`` etc.
	function ElementFactory:DependencyBox()
		return ElementFactory.AddDependencyBox(self)
	end

	function ElementFactory:AddDependencyBox()
		-- Linoria parity stub: simple container section beneath the caller
		local box = {
			Window = self._window,
			Page = self._body or self._page,
			_elements = {},
			_index = 0,
		}
		for k, v in pairs(ElementFactory) do
			box[k] = function(_, ...)
				return v(box, ...)
			end
		end
		return box
	end

	function ElementFactory:Divider(text)
		local opts = type(text) == "table" and text or { Text = text }
		local el = Shared.Components.Divider.New(MakeScope(self, opts.Text), opts)
		return Track(self, el, opts.Text or "")
	end

	function ElementFactory:ProgressBar(opts, value, max)
		if type(opts) == "string" then
			opts = { Title = opts, Value = value, Max = max }
		end
		opts = opts or {}
		local el = Shared.Components.ProgressBar.New(MakeScope(self, opts.Title), opts)
		return Track(self, el, opts.Title or "")
	end

	function ElementFactory:Image(opts, image, height)
		if type(opts) == "string" then
			opts = { Image = opts, Height = image }
		end
		opts = opts or {}
		local el = Shared.Components.Image.New(MakeScope(self, opts.Title or "image"), opts)
		return Track(self, el, opts.Title or "")
	end

	-- Common aliases (Rayfield / Fluent / Linoria conventions)
	ElementFactory.AddButton = ElementFactory.Button
	ElementFactory.AddToggle = ElementFactory.Toggle
	ElementFactory.AddSlider = ElementFactory.Slider
	ElementFactory.AddDropdown = ElementFactory.Dropdown
	ElementFactory.AddColorPicker = ElementFactory.ColorPicker
	ElementFactory.AddKeybind = ElementFactory.Keybind
	ElementFactory.AddInput = ElementFactory.Input
	ElementFactory.AddLabel = ElementFactory.Label
	ElementFactory.AddParagraph = ElementFactory.Paragraph
	ElementFactory.AddDivider = ElementFactory.Divider
	ElementFactory.AddProgressBar = ElementFactory.ProgressBar
	ElementFactory.AddImage = ElementFactory.Image

	----------------------------------------------------------------------
	-- Section
	----------------------------------------------------------------------

	Section.__index = Section

	-- Containers.Section.New(window, tab, title, opts) -> Section
	-- opts: { Icon, Side ("Left"|"Right"|nil for full-width), Collapsible }
	function Section.New(window, tab, title, opts)
		opts = opts or {}
		local self = setmetatable({}, Section)
		self._window = window
		self._tab = tab
		self._title = title or "Section"
		self._elements = {}
		self._index = 0
		self._fullWidth = opts.Side == nil

		-- outer frame
		local frame = Utility.New("Frame", {
			Name = "Section_" .. self._title,
			BackgroundColor3 = Theme:Get("Card"),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = opts.Parent or tab._page,
		})
		Utility.Round(frame, 10)
		Utility.Stroke(frame, "Stroke", 1, 0.5)
		Utility.Paint(frame, "BackgroundColor3", "Card")

		-- header
		local header = Utility.New("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = frame,
		})
		Utility.Pad(header, 10, 0, 10, 0)

		Utility.New("Frame", { -- accent pip
			Name = "Pip",
			BackgroundColor3 = Theme:Get("Accent"),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 3, 0, 14),
			Parent = header,
		})

		local titleLabel = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = self._title,
			TextColor3 = Theme:Get("Text"),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(1, -40, 1, 0),
			Parent = header,
		})
		Utility.Paint(titleLabel, "TextColor3", "Text")

		local collapseIcon
		if opts.Collapsible then
			collapseIcon = Utility.New("ImageLabel", {
				Name = "Chevron",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				Parent = header,
			})
			Shared.Icons:Apply(collapseIcon, "chevron-down")
			Utility.Paint(collapseIcon, "ImageColor3", "Muted")
		end

		-- body
		local body = Utility.New("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(0, 0, 0, 30),
			Parent = frame,
		})
		Utility.Pad(body, 8, 0, 8, 8)
		local layout = Utility.ListLayout(body, { Padding = 6 })

		self._frame = frame
		self._body = body
		self._page = body -- elements parent into body
		self._header = header
		self._collapsed = false

		-- collapse support
		if opts.Collapsible then
			local btn = Utility.New("TextButton", {
				Name = "CollapseHitbox",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				Parent = header,
			})
			btn.MouseButton1Click:Connect(function()
				self:SetCollapsed(not self._collapsed)
			end)
		end

		return self
	end

	function Section:SetCollapsed(collapsed)
		self._collapsed = collapsed
		local target = collapsed and 30 or (self._body.AbsoluteSize.Y + 38)
		Tween:Play(self._frame, "Snappy", { Size = UDim2.new(1, 0, 0, collapsed and 30 or math.max(target, 30)) })
		if not collapsed then
			-- return to automatic size after the reveal anim completes
			task.delay(0.35, function()
				if not self._collapsed and self._frame.Parent then
					self._frame.AutomaticSize = Enum.AutomaticSize.Y
				end
			end)
		else
			self._frame.AutomaticSize = Enum.AutomaticSize.None
		end
	end

	function Section:SetTitle(text)
		self._title = text
		self._header.Title.Text = text
	end

	function Section:Destroy()
		for _, el in ipairs(self._elements) do
			if el.Destroy then
				pcall(function() el:Destroy() end)
			end
		end
		if self._frame then
			self._frame:Destroy()
		end
	end

	-- Element methods mixed in from ElementFactory
	for k, v in pairs(ElementFactory) do
		Section[k] = v
	end

	----------------------------------------------------------------------
	-- GroupBox — a narrower card used for two-column layouts (Linoria side)
	----------------------------------------------------------------------

	GroupBox.__index = GroupBox

	-- Containers.GroupBox.New(window, parentColumn, title, opts)
	function GroupBox.New(window, parentColumn, title, opts)
		opts = opts or {}
		local self = setmetatable({}, GroupBox)
		self._window = window
		self._title = title or "Group"
		self._elements = {}
		self._index = 0

		local frame = Utility.New("Frame", {
			Name = "GroupBox_" .. self._title,
			BackgroundColor3 = Theme:Get("Card"),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = parentColumn,
		})
		Utility.Round(frame, 10)
		Utility.Stroke(frame, "Stroke", 1, 0.5)
		Utility.Paint(frame, "BackgroundColor3", "Card")

		-- header with icon support
		local head = Utility.New("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
			Parent = frame,
		})
		Utility.Pad(head, 10, 0, 10, 0)

		if opts.Icon then
			local icon = Utility.New("ImageLabel", {
				Name = "Icon",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				Parent = head,
			})
			Shared.Icons:Apply(icon, opts.Icon)
			Utility.Paint(icon, "ImageColor3", "Accent")
		end

		local titleLabel = Utility.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = self._title,
			TextColor3 = Theme:Get("Text"),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, opts.Icon and 20 or 0, 0, 0),
			Size = UDim2.new(1, -(opts.Icon and 20 or 0), 1, 0),
			Parent = head,
		})
		Utility.Paint(titleLabel, "TextColor3", "Text")

		local body = Utility.New("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.new(0, 0, 0, 28),
			Size = UDim2.new(1, 0, 0, 0),
			Parent = frame,
		})
		Utility.Pad(body, 8, 0, 8, 8)
		Utility.ListLayout(body, { Padding = 6 })

		self._frame = frame
		self._body = body
		self._page = body
		return self
	end

	function GroupBox:SetTitle(text)
		self._title = text
		self._frame.Header.Title.Text = text
	end

	function GroupBox:Destroy()
		for _, el in ipairs(self._elements) do
			if el.Destroy then
				pcall(function() el:Destroy() end)
			end
		end
		if self._frame then
			self._frame:Destroy()
		end
	end

	for k, v in pairs(ElementFactory) do
		GroupBox[k] = v
	end

	return { Section = Section, GroupBox = GroupBox, Factory = ElementFactory }
end
