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
		local dragStart = nil     -- Vector3 from input.Position
		local startPos = nil      -- UDim2 target.Position at drag start
		local goal = nil          -- UDim2 desired Position (offsets computed)

		local function clampGoal(x, y, size)
			if not opts.Bounds then
				return x, y
			end
			local cam = Services.Workspace.CurrentCamera
			local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
			local minX = -size.X + 48
			local maxX = vp.X - 48
			return math.clamp(x, minX, maxX), math.clamp(y, 0, math.max(vp.Y - 48, 60))
		end

		local conns = {}

		local DRAG_THRESHOLD = 3 -- px of movement before a drag begins
		local armed = false

		table.insert(conns, handle.InputBegan:Connect(function(input)
			if not state.Enabled or not Utility.IsClick(input) then
				return
			end
			armed = true
			dragging = false
			dragStart = input.Position
			startPos = target.Position
			local ended
			ended = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					armed = false
					if dragging then
						dragging = false
						if opts.OnDragEnd then
							pcall(opts.OnDragEnd, goal)
						end
					end
					ended:Disconnect()
				end
			end)
			table.insert(conns, ended)
		end))

		table.insert(conns, UIS.InputChanged:Connect(function(input)
			if not armed or not Utility.IsMove(input) then
				return
			end
			local delta = Vector2.new(input.Position.X - dragStart.X, input.Position.Y - dragStart.Y)
			if not dragging then
				if math.abs(delta.X) < DRAG_THRESHOLD and math.abs(delta.Y) < DRAG_THRESHOLD then
					return
				end
				dragging = true
				if opts.OnDragStart then
					pcall(opts.OnDragStart)
				end
			end
			local ox = startPos.X.Offset + delta.X
			local oy = startPos.Y.Offset + delta.Y
			ox, oy = clampGoal(ox, oy, target.AbsoluteSize)
			goal = UDim2.new(startPos.X.Scale, ox, startPos.Y.Scale, oy)
		end))

		-- smoothing pump
		table.insert(conns, RunService.RenderStepped:Connect(function()
			if not goal then
				return
			end
			local cur = target.Position
			local dx = goal.X.Offset - cur.X.Offset
			local dy = goal.Y.Offset - cur.Y.Offset
			if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then
				target.Position = goal
				if not dragging then
					goal = nil
				end
				return
			end
			target.Position = UDim2.new(
				goal.X.Scale, cur.X.Offset + dx * lerp,
				goal.Y.Scale, cur.Y.Offset + dy * lerp)
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
