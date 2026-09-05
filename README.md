# Tracium v2

A single-file Roblox UI library: dark by default, animated everywhere, and
self-contained. One `loadstring`, done. Design language borrows the best of
**Rayfield** (sidebar + notifications), **Fluent** (acrylic + ripples), **WindUI**
(card chrome + dialogs), **Linoria** (two-column groupboxes + config profiles),
**Orion** (concise window API) and **Kavo/Solaris**-style rapid section calls.

## Load

```lua
local Tracium = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/ItzE1ectric/Tracium/main/Tracium.lua"
))()
```

Or from the executor file system:

```lua
local Tracium = loadstring(readfile("path/to/Tracium.lua"))()
```

## Quick start

```lua
local Window = Tracium:CreateWindow({
	Title    = "My Hub",
	Subtitle = "production build",
	Icon     = "zap",          -- any lucide icon name
	Tag      = "v1.0",
	Theme    = "Midnight",     -- 16 built-in dark themes (+ Snow)
	ToggleKey = Enum.KeyCode.RightShift,
	ConfigFolder = "Tracium/MyHub",
	ConfigName   = "default",
	AutoLoadConfig = true,
	Acrylic  = true,           -- Lighting blur behind the UI
	Watermark = { Enabled = true, ShowFPS = true, ShowPing = true, ShowTime = true },
	SearchEnabled  = true,     -- sidebar search across every tab
	UserInfo  = true,          -- avatar card in the sidebar
	Resizable = true,          -- bottom-right grip
	-- LoadingEnabled = true, LoadingTitle = "...", LoadingSubtitle = "...",
	-- KeySystem = { Title = "...", Keys = { "ABC-123" } },  -- or Validate = function(key) return true end
})

local Main = Window:Tab("Main", "home")
Main:Section("Farm")

Main:Toggle({
	Title = "Auto Farm",
	Flag  = "AutoFarm",      -- persisted in configs
	Callback = function(on) end,
}):AddColorPicker({ Flag = "FarmColor" })
  :AddKeybind({ Flag = "FarmKey", Default = Enum.KeyCode.G }) -- chain via toggle handle?

Main:Slider({ Title = "Speed", Min = 16, Max = 500, Default = 16, Flag = "Speed",
	Suffix = " studs", Callback = function(v) end })

Main:Dropdown({ Title = "Mode", Values = { "Nearest", "Weakest" }, Default = "Nearest",
	Flag = "Mode", Callback = function(v) end })

Main:ColorPicker({ Title = "ESP Color", Flag = "ESP",
	Callback = function(color, alpha) end })

Main:Keybind({ Title = "Panic", Default = Enum.KeyCode.End, Mode = "Toggle",
	Callback = function(active) end })

Main:Input({ Title = "Webhook", Placeholder = "https://...", Flag = "Hook",
	FireOn = "Enter", Callback = function(text) end })

Main:Button("Run once", function()
	Window:Notify({ Title = "Hi", Content = "Toasts stack to the corner", Type = "Success" })
end)

Main:Paragraph({ Title = "Info", Content = "Multi-line copy", Icon = "info" })
Main:Label("Status: idle")
Main:Divider("extra")
Main:ProgressBar({ Title = "XP", Value = 35, Max = 100 })
Main:Image({ Title = "Preview", Image = "rbxassetid://12345", Height = 160 })
```

Window helpers: `Window:Notify` `Window:Dialog{...}` `Window:SetTheme(name)`
`Window:SelectTab(name|index)` `Window:Toggle() / :Show() / :Hide()` `Window:Save()` `Window:Load()`
`Window:SetTitle(text)` `Window:Destroy()`.

Global helpers: `Tracium.Flags`, `Tracium:Notify{}`, `Tracium:ThemeNames()`,
`Tracium.Shared` (escape hatch to internals).

## Layout options

* `Section` — full width rows.
* `GroupBox` — Linoria two-column: `Tab:AddLeftGroupbox("Aim", "crosshair")` /
  `Tab:AddRightGroupbox("Visuals", "eye")`.
* Elements can be created directly on a tab too (`Tab:Toggle(...)`).

## Themes

16 curated dark sets: Midnight · DeepSpace · Carbon · Dracula · Nord · Violet ·
Ocean · Aurora · Forest · Matcha · Ember · Cocoa · Crimson · Rose · Amber
(+ Snow, one light theme). Switching themes tweens every painted instance live.
Add your own: `Tracium.Shared.Theme:RegisterCustom(name, { Accent = Color3..., ... })` —
missing keys inherit from the current active theme.

## Configuration

Flags persist automatically (debounced) to `<Folder>/profiles/<name>.json` when
the executor exposes `writefile`. Profiles can be listed/renamed/autoloaded via
`Tracium.Shared.Config` or the built-in SaveManager controls. Color3/Enums
survive round-trips. In Studio or restricted environments the system falls back
to an in-memory store so the same code still runs.

## Notifications + dialogs

```lua
Tracium:Notify{ Title, Content, Type = "Info|Success|Warning|Error",
	Duration = 4, Icon = "bell", Actions = { { Label = "Undo", Callback = fn } } }

Window:Dialog{ Title, Content, Icon, Buttons = {
	{ Label = "Cancel" },
	{ Label = "Confirm", Primary = true, Callback = fn },
} }
```

## Repository layout

```
Tracium.lua          -- compiled single-file library (what you loadstring)
build.ps1            -- rebuilds the bundle from src/
Example.lua          -- full showcase
test/                -- headless Roblox mocks + assertion suite
	src/             -- modular sources (edit here, then .\build.ps1)
	  Core/          -- Signal, Tween, Theme, Config, Icons, Utility, ...
	  Components/    -- Button, Toggle, Slider, Dropdown, ColorPicker, ...
	  Containers/    -- Window, Tab, Section, GroupBox
	  Addons/        -- ThemeManager, SaveManager, KeybindList
	tools/           -- icon extraction
```

## Development

```powershell
.\build.ps1                                     # rebuild Tracium.lua from src/
$luau\luau-compile.exe .\Tracium.lua            # syntax check
$luau\luau.exe .\test\mock_run.lua              -- headless runtime tests
```

Icons: 286 lucide icons embedded via latte-soft/lucide-roblox (MIT) —
see `tools/ExtractIcons.ps1` to add more.

Icons are tinted at runtime, every element is registered with the injected
Overlay "search", and toggles/sliders/dropdowns/keybinds/color chips attach
nicely into Linoria-style mini chips via `:AddKeybind()` / `:AddColorPicker()`.

MIT where applicable; lucide icons are ISC.
