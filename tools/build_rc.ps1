# Builds the release-candidate APK from the "Android RC" preset.
#
# The RC preset carries the release_build feature and excludes scripts/debug,
# scripts/dev, scenes/dev and tests, so the M8-06 overlay cannot ship.
#
# Release signing needs the owner's keystore (M10-03). Until that exists the
# script falls back to a debug *build* of the same RC configuration, verifies
# that it is portrait-locked, and says plainly that it is debuggable and
# debug-signed. It is a release candidate, not a store build.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\build_rc.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_build_lib.ps1')

$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root 'godot'
$outDir = Join-Path $root 'builds'
$apk = Join-Path $outDir 'sort-master-rc.apk'
$preset = 'Android RC'

if (-not (Test-Path (Join-Path $project 'project.godot'))) { Write-Error "No project.godot in $project"; exit 2 }
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$godot = Resolve-Godot
$log = Join-Path $outDir 'build-rc.log'

function Invoke-Export([string]$mode, [string]$logPath) {
    foreach ($f in @($apk, "$apk.idsig")) { if (Test-Path $f) { Remove-Item $f -Force } }
    $ErrorActionPreference = 'Continue'
    $output = & $godot --headless --path $project ("--export-" + $mode) ('"' + $preset + '"') $apk 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $output | Set-Content -Path $logPath
    if ($code -ne 0) { Write-Host ("export-" + $mode + " exited " + $code) }
    return $code
}

$signedWith = 'release'
Invoke-Export 'release' (Join-Path $outDir 'build-rc-release.log') | Out-Null

if (-not (Test-ApkSigned $apk)) {
    Write-Host 'Release signing is not configured (M10-03). Falling back to a debug RC build.'
    $signedWith = 'debug'
    Invoke-Export 'debug' $log | Out-Null
}

if (-not (Test-Path $apk)) {
    Write-Host 'RC BUILD FAILED'
    Get-Content $log -ErrorAction SilentlyContinue | Select-Object -Last 20 | ForEach-Object { Write-Host ("  " + $_) }
    exit 1
}
if (-not (Test-ApkSigned $apk)) {
    Write-Host 'RC BUILD FAILED: the APK is not signed'
    exit 1
}

try {
    Assert-Apk -Path $apk -VersionCode 2 -RequirePortrait
} catch {
    Write-Host "RC VERIFICATION FAILED: $($_.Exception.Message)"
    exit 1
}

$debuggable = Get-ApkDebuggable $apk
$size = [math]::Round((Get-Item $apk).Length / 1MB, 2)
$kind = if ($debuggable) { 'debug build, debuggable, debug-signed' } else { "$signedWith-signed" }
Write-Host ("RC BUILD OK  {0}  ({1} MB, {2})" -f $apk, $size, $kind)

if ($debuggable) {
    Write-Host 'NOTE: this artifact is for internal testing only; M10-03 is still open.'
}
exit 0
