# Builds the release-candidate APK from the "Android RC" preset.
#
# The RC preset carries the release_build feature and excludes scripts/debug,
# scripts/dev, scenes/dev and tests, so the M8-06 overlay cannot ship.
#
# Release signing needs the owner's keystore (M10-03). Until that exists the
# script falls back to a debug-signed export of the same RC configuration and
# says so plainly: the artifact is a release candidate, not a store build.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\build_rc.ps1

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path -Parent $PSScriptRoot
$godot = 'C:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$project = Join-Path $root 'godot'
$outDir = Join-Path $root 'builds'
$apk = Join-Path $outDir 'sort-master-rc.apk'
$preset = 'Android RC'

if (-not (Test-Path $godot)) { Write-Error "Godot not found at $godot"; exit 2 }
if (-not (Test-Path (Join-Path $project 'project.godot'))) { Write-Error "No project.godot in $project"; exit 2 }

New-Item -ItemType Directory -Path $outDir -Force | Out-Null
foreach ($f in @($apk, "$apk.idsig")) { if (Test-Path $f) { Remove-Item $f -Force } }

$log = Join-Path $outDir 'build-rc.log'
$err = "$log.err"

function Invoke-Export([string]$mode) {
    foreach ($f in @($apk, $log, $err)) { if (Test-Path $f) { Remove-Item $f -Force } }
    $p = Start-Process -FilePath $godot `
        -ArgumentList '--headless', '--path', $project, ("--export-" + $mode), ('"' + $preset + '"'), $apk `
        -RedirectStandardOutput $log -RedirectStandardError $err `
        -PassThru -NoNewWindow
    $null = $p.WaitForExit(900000)
    $p.Refresh()
    return $p.ExitCode
}

function Test-Signed([string]$path) {
    if (-not (Test-Path $path)) { return $false }
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($path)
        $signed = @($zip.Entries | Where-Object { $_.FullName -match '^META-INF/.*\.(RSA|DSA|EC)$' }).Count -gt 0
        $zip.Dispose()
        return $signed
    } catch {
        return $false
    }
}

$signedWith = 'release'
Invoke-Export 'release' | Out-Null

if (-not (Test-Signed $apk)) {
    $keystoreMissing = $false
    if (Test-Path $err) {
        $keystoreMissing = @(Get-Content $err | Where-Object { $_ -match 'release keystore' }).Count -gt 0
    }
    if ($keystoreMissing -or -not (Test-Path $apk)) {
        Write-Host 'Release signing is not configured (M10-03). Falling back to a debug-signed RC export.'
    } else {
        Write-Host 'Release export produced no signed APK. Falling back to a debug-signed RC export.'
    }
    $signedWith = 'debug'
    Invoke-Export 'debug' | Out-Null
}

if (-not (Test-Path $apk)) {
    Write-Host 'RC BUILD FAILED'
    Get-Content $err -ErrorAction SilentlyContinue | Select-Object -First 15 | ForEach-Object { Write-Host ("  " + $_) }
    exit 1
}

if (-not (Test-Signed $apk)) {
    Write-Host 'RC BUILD FAILED: the APK is not signed'
    exit 1
}

$size = [math]::Round((Get-Item $apk).Length / 1MB, 2)
Write-Host ("RC BUILD OK  {0}  ({1} MB, {2}-signed)" -f $apk, $size, $signedWith)

$errors = @()
if (Test-Path $err) {
    $errors = Get-Content $err | Where-Object { $_ -match '^ERROR' -and $_ -notmatch 'project icon' -and $_ -notmatch 'release keystore' -and $_ -notmatch 'Project export for preset' }
}
if ($errors.Count -gt 0) {
    Write-Host 'warnings:'
    $errors | Select-Object -First 8 | ForEach-Object { Write-Host ("  " + $_) }
}
exit 0
