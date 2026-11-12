# Build Sort Master debug APK in one command.
# Usage: powershell -ExecutionPolicy Bypass -File tools\build_debug.ps1
# Exit code 0 on success, non-zero on any failure.

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$godot = 'C:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$project = Join-Path $root 'godot'
$outDir = Join-Path $root 'builds'
$apk = Join-Path $outDir 'sort-master.apk'

if (-not (Test-Path $godot)) { Write-Error "Godot not found at $godot"; exit 2 }
if (-not (Test-Path (Join-Path $project 'project.godot'))) { Write-Error "No project.godot in $project"; exit 2 }

New-Item -ItemType Directory -Path $outDir -Force | Out-Null
if (Test-Path $apk) { Remove-Item $apk -Force }
if (Test-Path "$apk.idsig") { Remove-Item "$apk.idsig" -Force }

$version = (& $godot --version 2>&1 | Out-String).Trim()
Write-Host "Godot: $version"

$log = Join-Path $outDir 'build.log'
$p = Start-Process -FilePath $godot `
    -ArgumentList '--headless', '--path', $project, '--export-debug', 'Android', $apk `
    -RedirectStandardOutput $log -RedirectStandardError "$log.err" `
    -PassThru -NoNewWindow
$null = $p.WaitForExit(600000)
$p.Refresh()

$errors = @()
if (Test-Path "$log.err") { $errors = Get-Content "$log.err" | Where-Object { $_ -match '^ERROR' -and $_ -notmatch 'project icon' } }

if (-not (Test-Path $apk)) {
    Write-Host "BUILD FAILED (exit $($p.ExitCode))"
    $errors | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$size = [math]::Round((Get-Item $apk).Length / 1MB, 2)
Write-Host "BUILD OK  $apk  ($size MB)"
if ($errors.Count -gt 0) {
    Write-Host "warnings:"
    $errors | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" }
}
exit 0
