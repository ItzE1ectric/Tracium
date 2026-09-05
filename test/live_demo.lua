-- Live smoke test: loads Tracium from GitHub main, builds a full demo window.
local Tracium = loadstring(game:HttpGet("https://raw.githubusercontent.com/ItzE1ectric/Tracium/main/Tracium.lua"))()

local Window = Tracium:CreateWindow({
	Title = "Tracium Live",
	Subtitle = "in-game smoke test",
	Tag = "v2",
	Theme = "Midnight",
	ToggleKey = Enum.KeyCode.RightShift,
	Acrylic = true,
	ConfigFolder = "Tracium",
	ConfigName = "livetest",
})

local Main = Window:Tab("Main", "home")
Main:Section("Live Controls")
Main:Paragraph({ Title = "Live test", Content = "Drag the topbar. Open the dropdown. Click every control.", Icon = "zap" })

local t = Main:Toggle({ Title = "ESP", Description = "sub-chips attached", Flag = "tESP", Callback = function(v) print("esp", v) end })
t:AddKeybind({ Flag = "tKey", Default = Enum.KeyCode.G })
t:AddColorPicker({ Flag = "tCol", Default = Color3.fromRGB(255, 60, 60) })

Main:Slider({ Title = "WalkSpeed", Min = 16, Max = 250, Default = 16, Flag = "tWS", Callback = function(v) end })
Main:Dropdown({ Title = "Mode", Values = { "Alpha", "Beta", "Gamma", "Delta", "Omega" }, Default = "Alpha", Flag = "tMode", Callback = print })
Main:Input({ Title = "Name", Placeholder = "type here", Flag = "tName", Callback = print })
Main:ColorPicker({ Title = "Outline", Default = Color3.fromRGB(120, 170, 255), Flag = "tOut", Callback = print })
Main:ProgressBar({ Title = "Level", Value = 45, Max = 100 })
Main:Button("Ping", function()
	Window:Notify({ Title = "Pong", Content = "Toasts work", Type = "Success", Duration = 3 })
end)

local Gfx = Window:Tab("Second", "settings")
Gfx:AddLeftGroupbox("Left", "box"):Toggle({ Title = "Thing A", Flag = "gA" })
Gfx:AddRightGroupbox("Right", "shield"):Slider({ Title = "Amount", Min = 0, Max = 100, Default = 30 })

Window:Notify({ Title = "Tracium", Content = "Live build loaded", Type = "Info", Duration = 4 })
print("[live-demo] window built OK")
