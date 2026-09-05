<#
.SYNOPSIS
  Bundles every src/*.lua module into a single distributable Tracium.lua so
  the whole library loads via one loadstring:

      local Tracium = loadstring(game:HttpGet(
          "https://raw.githubusercontent.com/USER/Tracium/main/Tracium.lua"))()

  Usage:  .\build.ps1
#>

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$src = Join-Path $PSScriptRoot "src"

# load order matters: core first (dependency order), then components,
# then containers, then addons, Init last (it runs the loader).
$order = @(
	"Core\Signal.lua",
	"Core\Utility.lua",
	"Core\Tween.lua",
	"Core\IconMap.lua",
	"Core\Icons.lua",
	"Core\Drag.lua",
	"Core\Acrylic.lua",
	"Core\Tooltip.lua",
	"Core\Theme.lua",
	"Core\Notify.lua",
	"Core\Config.lua",
	"Components\Button.lua",
	"Components\Toggle.lua",
	"Components\Slider.lua",
	"Components\Dropdown.lua",
	"Components\ColorPicker.lua",
	"Components\Keybind.lua",
	"Components\Input.lua",
	"Components\Label.lua",
	"Components\Paragraph.lua",
	"Components\Divider.lua",
	"Components\ProgressBar.lua",
	"Components\Image.lua",
	"Components\Dialog.lua",
	"Containers\Section.lua",
	"Containers\Tab.lua",
	"Containers\Window.lua",
	"Addons\ThemeManager.lua",
	"Addons\SaveManager.lua",
	"Addons\KeybindList.lua",
	"Init.lua"
)

$header = @"
--[===========================================================================[
	Tracium v2 — bundled single-file distribution (auto-generated)
	Built by build.ps1 — do not edit; edit src/*.lua then rebuild.
	Loads with: loadstring(...)()
]===========================================================================]

"@

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine($header)
[void]$sb.AppendLine("local __MODULES = {}")

foreach ($rel in $order) {
	$path = Join-Path $src $rel
	if (-not (Test-Path $path)) {
		throw "missing module $rel"
	}
	$content = Get-Content $path -Raw
	$modName = ($rel -replace "\\", ".") -replace "\.lua$", ""
	[void]$sb.AppendLine("")
	[void]$sb.AppendLine(("--===========================[ $modName ]===========================--"))
	[void]$sb.AppendLine("__MODULES[`"$modName`"] = (function()")
	[void]$sb.AppendLine($content)
	[void]$sb.AppendLine("end)()")
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("-- bootstrap: constructors map -> Init")
[void]$sb.AppendLine("return __MODULES[`"Init`"](__MODULES)")

$outPath = Join-Path $root "Tracium.lua"
[System.IO.File]::WriteAllText($outPath, $sb.ToString())

$lines = ($sb.ToString() -split "`n").Count
Write-Host ("Wrote {0} ({1} lines, {2:N0} bytes)" -f $outPath, $lines, (Get-Item $outPath).Length)
