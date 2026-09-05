--[[==========================================================================]]
-- Tracium v2 · Core/Drag.lua
-- Smooth, lerped window/element dragging (mouse + touch). Standard
-- InputBegan/InputChanged model with a RenderStepped smoothing pump.
--
--   local h = Drag:MakeDraggable(handleFrame, targetFrame, {
--       Lerp = 0.35,          -- smoothing factor per frame (0..1]; 1 = none
--       Bounds = true,        -- keep target on screen (default true)
--       OnDragStart = fn, OnDragEnd = fn,
--   })
--   h:Destroy(); h:SetLerp(n); h.Enabled = false
--[[==========================================================================]]

return function(Shared)
	local Drag = {}
	local Services = Shared.Services
	local UIS = Services.UserInputService
	local RunService = Services.RunService
	local Utility = Shared.Utility

	function Drag:MakeDraggable(handle, target, opts)
		opts = opts or {}
		target = target or handle
		local lerp = opts.Lerp or 0.3
		if opts.Bounds == nil then
			opts.Bounds = true
		end

		local state = { Enabled = true }
		local dragging = false
		local dragStart = nil   -- Vector3 from input.Position
		local startAbs = nil    -- Vector2 target.AbsolutePosition
		local goal = nil        -- Vector2 desired absolute position

		local function clampGoal(g, size)
			if not opts.Bounds then
				return g
			end
			local cam = Services.Workspace.CurrentCamera
			local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
			local x = math.clamp(g.X, -size.X + 48, vp.X - 48)
			local y = math.clamp(g.Y, 0, math.max(vp.Y - 48, 60))
			return Vector2.new(x, y)
		end

		local conns = {}

		table.insert(conns, handle.InputBegan:Connect(function(input)
			if not state.Enabled or not Utility.IsClick(input) then
				return
			end
			dragging = true
			dragStart = input.Position
			startAbs = target.AbsolutePosition
			if opts.OnDragStart then
				pcall(opts.OnDragStart)
			end
			local ended
			ended = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					ended:Disconnect()
					if opts.OnDragEnd then
						pcall(opts.OnDragEnd, goal)
					end
				end
			end)
			table.insert(conns, ended)
		end))

		table.insert(conns, UIS.InputChanged:Connect(function(input)
			if not dragging or not Utility.IsMove(input) then
				return
			end
			local delta = Vector2.new(input.Position.X - dragStart.X, input.Position.Y - dragStart.Y)
			goal = clampGoal(startAbs + delta, target.AbsoluteSize)
		end))

		-- smoothing pump
		table.insert(conns, RunService.RenderStepped:Connect(function()
			if not goal then
				return
			end
			local cur = target.AbsolutePosition
			local dx = goal.X - cur.X
			local dy = goal.Y - cur.Y
			if math.abs(dx) < 0.4 and math.abs(dy) < 0.4 then
				target.Position = UDim2.new(0, goal.X, 0, goal.Y)
				if not dragging then
					goal = nil
				end
				return
			end
			target.Position = UDim2.new(0, cur.X + dx * lerp, 0, cur.Y + dy * lerp)
		end))

		function state:SetLerp(v)
			lerp = math.clamp(v or 0.3, 0.05, 1)
		end

		function state:Destroy()
			dragging = false
			goal = nil
			for _, c in ipairs(conns) do
				pcall(function()
					c:Disconnect()
				end)
			end
		end

		return state
	end

	return Drag
end
