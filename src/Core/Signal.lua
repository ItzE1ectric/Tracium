--[[==========================================================================]]
-- Tracium v2 · Core/Signal.lua
-- Lightweight, dependency-free signal/event implementation.
-- API is compatible with the classic "Quenty-lite" style signals:
--   local sig = Signal.new()
--   local conn = sig:Connect(function(a, b) ... end)
--   sig:Fire(1, 2)           -- fires all handlers in spawned threads
--   sig:FireSync(1, 2)       -- fires inline (errors propagate to caller)
--   local a, b = sig:Wait()  -- yields until next Fire
--   conn:Disconnect()
--   sig:Destroy()
--[[==========================================================================]]

return function(Shared)
	local Signal = {}
	Signal.__index = Signal

	local Connection = {}
	Connection.__index = Connection

	function Connection.new(signal, fn)
		return setmetatable({
			Connected = true,
			_signal = signal,
			_fn = fn,
		}, Connection)
	end

	function Connection:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		local handlers = self._signal._handlers
		for i, conn in ipairs(handlers) do
			if conn == self then
				table.remove(handlers, i)
				break
			end
		end
		if self._once then
			self._signal = nil
		end
	end

	function Signal.new()
		return setmetatable({
			_handlers = {},
			_bound = false,
		}, Signal)
	end

	function Signal:IsSignal()
		return true
	end

	function Signal:Connect(fn)
		assert(type(fn) == "function", "Signal:Connect expects a function")
		local conn = Connection.new(self, fn)
		table.insert(self._handlers, conn)
		return conn
	end

	function Signal:Once(fn)
		local conn
		conn = self:Connect(function(...)
			conn:Disconnect()
			fn(...)
		end)
		conn._once = true
		return conn
	end

	function Signal:Fire(...)
		-- Snapshot: a handler disconnecting or connecting during Fire
		-- must not corrupt the iteration.
		local handlers = self._handlers
		local snapshot = table.create(#handlers)
		for i, conn in ipairs(handlers) do
			snapshot[i] = conn
		end
		for _, conn in ipairs(snapshot) do
			if conn.Connected then
				task.spawn(conn._fn, ...)
			end
		end
	end

	function Signal:FireSync(...)
		local snapshot = table.create(#self._handlers)
		for i, conn in ipairs(self._handlers) do
			snapshot[i] = conn
		end
		for _, conn in ipairs(snapshot) do
			if conn.Connected then
				conn._fn(...)
			end
		end
	end

	function Signal:Wait()
		local thread = coroutine.running()
		local conn
		conn = self:Connect(function(...)
			conn:Disconnect()
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end

	function Signal:DisconnectAll()
		for _, conn in ipairs(self._handlers) do
			conn.Connected = false
		end
		table.clear(self._handlers)
	end

	function Signal:Destroy()
		self:DisconnectAll()
		setmetatable(self, nil)
	end

	function Signal:Count()
		return #self._handlers
	end

	return Signal
end
