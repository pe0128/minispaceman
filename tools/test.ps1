param([string]$Godot = 'D:\godot\Godot_v4.7.2-stable_win64_console.exe', [switch]$Visual)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& $Godot --headless --editor --path $projectRoot --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& $Godot --headless --path $projectRoot --script res://tests/run_tests.gd
if ($LASTEXITCODE -ne 0) { throw 'Logic tests failed' }
& $Godot --headless --path $projectRoot --script res://tests/gameplay_tests.gd
if ($LASTEXITCODE -ne 0) { throw 'Gameplay tests failed' }
if ($Visual) {
    & $Godot --path $projectRoot -- --smoke-test
    if ($LASTEXITCODE -ne 0) { throw 'Visual smoke test failed' }
    & $Godot --path $projectRoot -- --integration-test
    if ($LASTEXITCODE -ne 0) { throw 'Native integration test failed' }
    python (Join-Path $PSScriptRoot 'ui_smoke_windows.py')
    if ($LASTEXITCODE -ne 0) { throw 'Native input routing test failed' }
}
