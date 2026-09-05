-- Runs the bundled Tracium against the mock Roblox environment.
-- Use tools to generate the harness:  powershell -File tools\RunMock.ps1
local Mock = require("./mock")
local env = Mock.BuildEnv()

-- bundle source is injected by tools/make_test_bundle.ps1 into test/bundle_src.lua
local bundleSrc = require("./bundle_src")
local Tracium = Mock.RunSource(env, bundleSrc, "@Tracium")

print("[mock] loaded lib version:", Tracium.Version)
assert(type(Tracium) == "table")
assert(type(Tracium.CreateWindow) == "function")

env.task._pump(400)

local Window = Tracium:CreateWindow({
	Title = "MockHub",
	Subtitle = "test",
	Theme = "Midnight",
})
assert(type(Window) == "table")
env.task._pump(400)

local Main = Window:Tab("Main", "home")
Main:Section("Controls")

local toggled
local t = Main:Toggle("Test toggle", false, function(v)
	toggled = v
end)
t:Set(true)
assert(t:Get() == true, "toggle Set/Get")

local s = Main:Slider("Speed", 0, 100, 25, function() end)
s:Set(50)
assert(s:Get() == 50, "slider Set/Get")

local d = Main:Dropdown("Mode", { "A", "B", "C" }, "A", function() end)
d:Set("B")
assert(d:Get() == "B", "dropdown Set/Get")

local inp = Main:Input("Name", "type...", function() end)
inp:Set("hello")
assert(inp:Get() == "hello", "input Set/Get")

local kb = Main:Keybind("Panic", "X", function() end)
kb:SetKey("Q")
assert(kb:GetKey() and kb:GetKey().Name == "Q" or kb:Get() == "Q", "keybind set")

local cp = Main:ColorPicker("Tint", env.Color3.fromRGB(255, 0, 0), function() end)
local c = cp:Get()
assert(type(c) == "table" and c.R ~= nil, "colorpicker returns color")

Main:Label("Label text")
Main:Paragraph("Title here", "Body content")
Main:Divider("Split")
local pb = Main:ProgressBar("Progress", 25, 100)
pb:Set(75)
assert(pb:Get() == 75, "progress Get")

local ComTab = Window:Tab("Combat", "swords")
local left = ComTab:AddLeftGroupbox("Left Box", "box")
local right = ComTab:AddRightGroupbox("Right Box", "shield")
left:Toggle("BoxLeft", true, function() end)
right:Slider("Amount", 0, 10, 5, function() end)

Window:Notify({ Title = "Test", Content = "notify from mock", Duration = 2 })
Window:Dialog({ Title = "Sure?", Buttons = { { Label = "OK" } } })
Window:SetTheme("Dracula")
Window:SetTheme("Midnight")
env.task._pump(600)

Window:Toggle() -- hide
Window:Toggle() -- show

print("[mock] themes:", table.concat(Tracium:ThemeNames(), ", "))
print("[mock] tabs created:", #Window.TabOrder)
print("[mock] ============================================")
print("[mock] ALL ASSERTIONS PASSED — bundle is functional")
