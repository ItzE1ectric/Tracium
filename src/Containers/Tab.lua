--[[==========================================================================]]
-- Tracium v2 · Containers/Tab.lua
-- A tab = one sidebar entry + one scrollable content page.
--
--   local Tab = Window:Tab("Main", "home")  -- or Window:CreateTab({...})
--   Tab:Section("Farm")                     -- full-width section
--   Tab:Toggle(...)                         -- element directly on page
--   Tab:AddLeftGroupbox("Aimbot")           -- two-column Linoria-style layout
--   Tab:AddRightGroupbox("Visuals", "eye")
--[[==========================================================================]]

return function(Shared)
	local Tab = {}
	Tab.__index = Tab

	local Utility = Shared.Utility
	local Theme = Shared.Theme
	local Containers = Shared.Containers

	-- Tab.New(window, name, icon) -> Tab
	function Tab.New(window, name, iconName)
		local self = setmetatable({}, Tab)
		self._window = window
		self._name = name or "Tab"
		self._icon = iconName
		self._elements = {}
		self._index = 0
		self._layoutOrder = 0
		self._columnRow = nil

		local page = Utility.New("ScrollingFrame", {
			Name = "Page_" .. self._name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme:Get("Muted"),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Visible = false,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			Parent = window._contentHost,
		})
		Utility.Paint(page, "ScrollBarImageColor3", "Muted")
		Utility.Pad(page, 12, 12, 14, 12)
		local layout = Utility.ListLayout(page, { Padding = 10 })
		Utility.ConnectCanvas(page, layout, 14)

		self._page = page
		self._body = page -- sections treat tab page like a body
		return self
	end

	----------------------------------------------------------------------
	-- Creation helpers
	----------------------------------------------------------------------

	local function nextOrder(self)
		self._layoutOrder += 1
		return self._layoutOrder
	end

	-- Tab:Section("Name") | Tab:Section("Name", { Icon, Collapsible, Side })
	function Tab:CreateSection(title, opts)
		local section = Containers.Section.New(self._window, self, title, opts)
		section._frame.LayoutOrder = nextOrder(self)
		return section
	end
	Tab.AddSection = Tab.CreateSection

	-- Legacy v1: Tabs double as sections (elements go straight to page)
	Tab.Section = Tab.CreateSection

	----------------------------------------------------------------------
	-- GroupBox columns (Linoria-style side-by-side)
	----------------------------------------------------------------------

	function Tab:_columns()
		if self._columnRow then
			return self._columnRow
		end
		local row = Utility.New("Frame", {
			Name = "Columns",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = nextOrder(self),
			Parent = self._page,
		})
		Utility.ListLayout(row, { Direction = "Horizontal", Padding = 10 })

		local function column(name)
			local col = Utility.New("Frame", {
				Name = name,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(0.5, -5, 0, 0),
				Parent = row,
			})
			Utility.ListLayout(col, { Padding = 10 })
			return col
		end

		self._columnRow = {
			Frame = row,
			Left = column("Left"),
			Right = column("Right"),
		}
		return self._columnRow
	end

	function Tab:AddLeftGroupbox(title, icon)
		local cols = self:_columns()
		local box = Containers.GroupBox.New(self._window, cols.Left, title, { Icon = icon })
		box._tab = self
		return box
	end

	function Tab:AddRightGroupbox(title, icon)
		local cols = self:_columns()
		local box = Containers.GroupBox.New(self._window, cols.Right, title, { Icon = icon })
		box._tab = self
		return box
	end

	-- Rayfield-ish alias
	Tab.LeftGroupBox = Tab.AddLeftGroupbox
	Tab.RightGroupBox = Tab.AddRightGroupbox

	----------------------------------------------------------------------
	-- Tab state / cleanup
	----------------------------------------------------------------------

	function Tab:SetVisible(visible)
		self._page.Visible = visible
	end

	function Tab:Destroy()
		for _, el in ipairs(self._elements) do
			if el.Destroy then
				pcall(function()
					el:Destroy()
				end)
			end
		end
		if self._page then
			self._page:Destroy()
		end
	end

	-- Elements can live directly on the tab page (v1 style: Tab:Toggle(...))
	-- by mixing in the element factory.
	local factory = Containers.Factory
	for k, v in pairs(factory) do
		Tab[k] = v
	end

	return Tab
end
