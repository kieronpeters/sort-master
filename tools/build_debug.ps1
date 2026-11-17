# Build Sort Master's debug APK in one command.
# Usage: powershell -ExecutionPolicy Bypass -File tools\build_debug.ps1
# Override the engine with $env:GODOT if it is not at the documented path.
# Exit code 0 on success, non-zero on any failure.

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_build_lib.ps1')
Initialize-GodotUserData | Out-Null

$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root 'godot'
$outDir = Join-Path $root 'builds'
$apk = Join-Path $outDir 'sort-master.apk'

if (-not (Test-Path (Join-Path $project 'project.godot'))) { Write-Error "No project.godot in $project"; exit 2 }

New-Item -ItemType Directory -Path $outDir -Force | Out-Null
foreach ($f in @($apk, "$apk.idsig")) { if (Test-Path $f) { Remove-Item $f -Force } }

$godot = Resolve-Godot
$version = (& $godot --version 2>&1 | Out-String).Trim()
Write-Host "Godot: $version"

$log = Join-Path $outDir 'build.log'
$ErrorActionPreference = 'Continue'
$output = & $godot --headless --path $project --export-debug Android $apk 2>&1
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
$output | Set-Content -Path $log

if ($code -ne 0 -or -not (Test-Path $apk)) {
    Write-Host "BUILD FAILED (exit $code)"
    $output | Where-Object { $_ -match 'ERROR' } | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

try {
    Assert-Apk -Path $apk -VersionCode 2
} catch {
    Write-Host "APK VERIFICATION FAILED: $($_.Exception.Message)"
    exit 1
}

$size = [math]::Round((Get-Item $apk).Length / 1MB, 2)
Write-Host "BUILD OK  $apk  ($size MB)"

$errors = $output | Where-Object { $_ -match '^ERROR' }
if ($errors) {
    Write-Host 'warnings:'
    $errors | Select-Object -First 8 | ForEach-Object { Write-Host "  $_" }
}
exit 0
