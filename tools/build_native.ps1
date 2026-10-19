param(
    [string]$Godot = 'D:\godot\Godot_v4.7.2-stable_win64_console.exe',
    [ValidateSet('template_debug','template_release')][string]$Target = 'template_debug'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    if (-not (Test-Path native/godot-cpp/SConstruct)) {
        git submodule update --init --depth 1
        if ($LASTEXITCODE -ne 0) { throw 'Cannot fetch godot-cpp' }
    }
    if (-not (Test-Path .tools/venv/Scripts/python.exe)) { python -m venv .tools/venv }
    $pythonPath = Join-Path $projectRoot '.tools/venv/Scripts/python.exe'
    & $pythonPath -m pip install --disable-pip-version-check -q 'scons==4.11.1'
    if ($LASTEXITCODE -ne 0) { throw 'SCons install failed' }
    New-Item -ItemType Directory -Force native/.build | Out-Null
    Push-Location native/.build
    try { & $Godot --headless --dump-extension-api } finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { throw 'Cannot dump Godot API' }
    Push-Location native
    try {
        & $pythonPath -m SCons platform=windows arch=x86_64 target=$Target custom_api_file=.build/extension_api.json build_profile=build_profile.json -j4
        if ($LASTEXITCODE -ne 0) { throw 'Native extension compilation failed' }
    } finally { Pop-Location }
} finally { Pop-Location }
