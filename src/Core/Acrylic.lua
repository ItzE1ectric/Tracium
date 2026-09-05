--[[==========================================================================]]
-- Tracium v2 · Core/Acrylic.lua
-- Screen blur ("acrylic") management via Lighting BlurEffect. One BlurEffect
-- instance serves every Tracium window; refcounted so multiple windows don't
-- double-blur or fight.
--
--   Acrylic:Attach()   -> claim   (returns true if blur available)
--   Acrylic:Release()  -> release one claim
--   Acrylic:SetIntensity(n)   0..64 (default 16)
--   Acrylic:SetEnabled(bool)
--[[==========================================================================]]

return function(Shared)
	local Acrylic = {}

	local Lighting = Shared.Services.Lighting
	local blur = nil
	local claims = 0
	local intensity = 16
	local enabled = true

	local function ensure()
		if blur and blur.Parent then
			return blur
		end
		local ok, eff = pcall(function()
			return Shared.Utility.New("BlurEffect", {
				Name = "TraciumAcrylic",
				Size = 0,
				Parent = Lighting,
			})
		end)
		if ok then
			blur = eff
			return blur
		end
		return nil
	end

	local function applyTarget()
		if not blur or not blur.Parent then
			return
		end
		local target = (enabled and claims > 0) and intensity or 0
		Shared.Tween:Play(blur, { Time = 0.4, Style = "Quart", Direction = "Out" }, { Size = target })
	end

	function Acrylic:Attach()
		claims += 1
		if ensure() then
			applyTarget()
			return true
		end
		return false
	end

	function Acrylic:Release()
		claims = math.max(claims - 1, 0)
		applyTarget()
	end

	function Acrylic:IsActive()
		return blur ~= nil and blur.Parent ~= nil and claims > 0 and enabled
	end

	function Acrylic:SetIntensity(n)
		intensity = math.clamp(tonumber(n) or 16, 0, 64)
		applyTarget()
	end

	function Acrylic:GetIntensity()
		return intensity
	end

	function Acrylic:SetEnabled(v)
		enabled = not not v
		if not enabled then
			applyTarget()
		else
			if claims > 0 and ensure() then
				applyTarget()
			end
		end
	end

	function Acrylic:IsEnabled()
		return enabled
	end

	function Acrylic:Destroy()
		claims = 0
		if blur and blur.Parent then
			local b = blur
			Shared.Tween:Play(b, "Fast", { Size = 0 })
			task.delay(0.3, function()
				if b.Parent then
					b:Destroy()
				end
			end)
			blur = nil
		end
	end

	return Acrylic
end
