--[[==========================================================================]]
	Tracium v2 — Showcase example. Exercises every control and feature.

	Load order:
	  1. Publish Tracium.lua to GitHub and use:
	       loadstring(game:HttpGet("https://raw.githubusercontent.com/ItzE1ectric/Tracium/main/Tracium.lua"))()
	  2. Executors with readfile: loadstring(readfile(".../Tracium.lua"))()
--[[==========================================================================]]

local Tracium = loadstring(game:HttpGet("https://raw.githubusercontent.com/ItzE1ectric/Tracium/main/Tracium.lua"))()

local Window = Tracium:CreateWindow({
	Title = "Tracium Hub",
	Subtitle = "v2 showcase",
	Icon = "zap",
	Tag = "2.0",
	Theme = "Midnight",
	Size = UDim2.fromOffset(700, 520),
	ToggleKey = Enum.KeyCode.RightShift,
	SearchEnabled = true,
	Acrylic = true,
	UserInfo = true,
	Resizable = true,
	ConfigFolder = "TraciumDemo",
	ConfigName = "default",
	AutoLoadConfig = true,
	Watermark = { Enabled = true, ShowFPS = true, ShowPing = true },
})

----------------------------------------------------------------------------
-- Tab 1: simple section-based layout
----------------------------------------------------------------------------

local Main = Window:Tab("Main", "home")

Main:Section("Getting Started")
Main:Paragraph({
	Title = "Welcome to Tracium v2",
	Content = "Every element below animated, themed, searchable and config-backed.",
	Icon = "info",
})

Main:Button({
	Title = "Say Hello",
	Description = "Basic button with a ripple",
	Icon = "bell",
	Callback = function()
		Window:Notify({ Title = "Hello!", Content = "You clicked the button.", Type = "Success", Duration = 3 })
	end,
})

Main:Button({
	Title = "Dangerous button",
	Description = "Hold-to-confirm keeps you safe",
	Variant = "Danger",
	HoldToConfirm = true,
	Callback = function()
		Window:Notify({ Title = "Done", Content = "Confirmed action ran", Type = "Warning", Duration = 3 })
	end,
})

Main:Section("Controls")

local autoFarm = Main:Toggle({
	Title = "Auto Farm",
	Description = "Uses the target below",
	Flag = "AutoFarm",
	Default = false,
	Callback = function(on)
		print("AutoFarm:", on)
	end,
})

autoFarm:AddKeybind({
	Flag = "AutoFarmKey",
	Default = Enum.KeyCode.G,
	Mode = "Toggle",
})

autoFarm:AddColorPicker({
	Flag = "AutoFarmColor",
	Default = Color3.fromRGB(88, 148, 255),
	Callback = function(c)
		print("farm marker color:", c)
	end,
})

Main:Slider({
	Title = "WalkSpeed",
	Min = 16, Max = 200, Default = 16, Suffix = "", Flag = "WalkSpeed",
	Callback = function(v)
		local h = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if h then h.WalkSpeed = v end
	end,
})

Main:Dropdown({
	Title = "Target Mode",
	Values = { "Nearest", "Lowest HP", "Highest HP", "Crew Only" },
	Default = "Nearest",
	Flag = "TargetMode",
	Callback = function(v) print("mode:", v) end,
})

Main:Dropdown({
	Title = "Damage Types",
	Values = { "Fire", "Ice", "Lightning", "Dark", "Holy" },
	Default = { "Fire" },
	Multi = true,
	Flag = "DamageTypes",
	Callback = function(list) print("types:", table.concat(list, ", ")) end,
})

Main:Input({
	Title = "Webhook URL",
	Placeholder = "https://discord.com/api/webhooks/...",
	Flag = "Webhook",
	FireOn = "Enter",
	Callback = function(text) print("webhook:", text) end,
})

Main:Keybind({
	Title = "Panic Key",
	Default = Enum.KeyCode.End,
	Mode = "Toggle",
	Callback = function(active)
		if active then Window:Hide() end
	end,
})

Main:ColorPicker({
	Title = "ESP Color",
	Flag = "ESPColor",
	Default = Color3.fromRGB(120, 180, 255),
	Callback = function(c) print("esp color:", c) end,
})

Main:ProgressBar({ Title = "XP Progress", Value = 30, Max = 100 })
Main:Divider("below is for display")
Main:Label("Static text with an icon")
Main:Image({ Title = "Preview", Icon = "image" })

----------------------------------------------------------------------------
-- Tab 2: Linoria-style two-column groupboxes
----------------------------------------------------------------------------

local Visuals = Window:Tab("Visuals", "eye")

Visuals:AddLeftGroupbox("ESP", "boxes"):Toggle({
	Title = "Box ESP", Flag = "BoxESP", Default = true,
	Callback = function(v) end,
})
Visuals:AddRightGroupbox("Lighting", "sun"):ColorPicker({
	Title = "Ambient", Flag = "Ambient", Default = Color3.fromRGB(70, 70, 80),
	Callback = function(c) game.Lighting.Ambient = c end,
})

----------------------------------------------------------------------------
-- Tab 3: config & demo of every notification type
----------------------------------------------------------------------------

local Misc = Window:Tab("Misc", "settings-2")

Misc:Section("Notifications")
for _, kind in ipairs({ "Info", "Success", "Warning", "Error" }) do
	Misc:Button("Notify " .. kind, function()
		Window:Notify({
			Title = kind .. " notification",
			Content = "This is what a " .. kind:lower() .. " toast looks like.",
			Type = kind,
			Duration = 3,
		})
	end)
end

Misc:Section("Dialog")
Misc:Button("Ask for confirmation", function()
	Window:Dialog({
		Title = "Wipe all flags?",
		Content = "This resets every option in this window to defaults.",
		Icon = "alert-triangle",
		Buttons = {
			{ Label = "Cancel" },
			{ Label = "Wipe", Primary = true, Danger = true, Callback = function()
				Tracium.Shared.Config:ResetToDefaults()
			end },
		},
	})
end)

Misc:Section("Theme")
Misc:Dropdown({
	Title = "Palette",
	Values = Tracium.Shared.Theme:Names(),
	Default = "Midnight",
	Callback = function(name) Window:SetTheme(name) end,
	Searchable = true,
})

Window:Notify({
	Title = "Tracium",
	Content = "Showcase loaded — Right Shift toggles the menu.",
	Duration = 4,
	Type = "Success",
})
