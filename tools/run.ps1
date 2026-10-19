param([string]$Godot = 'D:\godot\Godot_v4.7.2-stable_win64.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $projectRoot 'native/bin/minispaceman.windows.template_debug.x86_64.dll'))) {
    & (Join-Path $PSScriptRoot 'build_native.ps1') -Godot $Godot
}
& $Godot --path $projectRoot
