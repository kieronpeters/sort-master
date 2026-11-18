# Physical device pass for Sort Master.
#
# This is the S23 Ultra run from docs/device-validation.md, automated where the
# phone allows it. It deliberately does NOT disable Vulkan: the whole point is to
# find out whether the shipped Vulkan mobile renderer draws on real hardware,
# which no emulator backend here could do.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools\device_pass.ps1
#   powershell -ExecutionPolicy Bypass -File tools\device_pass.ps1 -Apk builds\sort-master.apk
#
# Exit code 0 only when every automated check passes.

param(
    [string]$Apk = "builds\sort-master-rc.apk",
    [string]$Serial = ""
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '_build_lib.ps1')

$root = Split-Path -Parent $PSScriptRoot
$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$outDir = Join-Path $root 'builds\device-pass'
$pkg = 'com.prismgarden.sortmaster'

if (-not (Test-Path $adb)) { Write-Host "adb not found at $adb"; exit 2 }
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
Get-ChildItem $outDir -Filter '*.png' -ErrorAction SilentlyContinue | Remove-Item -Force

$dev = if ($Serial) { @('-s', $Serial) } else { @() }
$results = New-Object System.Collections.Generic.List[string]
$failures = 0

function Check {
    param([string]$name, [bool]$ok, [string]$detail)
    if ($ok) { Write-Host ("PASS  {0,-36} {1}" -f $name, $detail) }
    else { Write-Host ("FAIL  {0,-36} {1}" -f $name, $detail); $script:failures++ }
    $verdict = if ($ok) { 'PASS' } else { 'FAIL' }
    $script:results.Add("| $name | $verdict | $detail |")
}

function A { param([Parameter(ValueFromRemainingArguments = $true)][string[]]$rest)
    return (& $adb @dev @rest 2>&1 | Out-String).Trim() }

function Shot {
    param([string]$name)
    $local = Join-Path $outDir "$name.png"
    & $adb @dev shell screencap -p /sdcard/dp.png 2>&1 | Out-Null
    & $adb @dev pull /sdcard/dp.png $local 2>&1 | Out-Null
    return $local
}

function Lit {
    param([string]$file)
    $out = & py -3.12 (Join-Path $PSScriptRoot 'png_stats.py') nonblack $file 2>&1 | Out-String
    if ($out -match 'lit=([0-9.]+)') { return [double]$Matches[1] }
    return -1
}

# --- find a real device ------------------------------------------------------
$list = A devices -l
if ($list -notmatch 'device\s+.*model:') {
    Write-Host 'No physical device attached.'
    Write-Host $list
    Write-Host ''
    Write-Host 'On the phone: Settings > About phone > Software information > tap'
    Write-Host '"Build number" 7 times, then Settings > Developer options >'
    Write-Host '"USB debugging" on, and accept the RSA prompt on the phone.'
    exit 2
}
if ($list -match 'emulator-') {
    Check 'target is a physical device' $false 'an emulator is attached; this pass must run on the phone'
    exit 2
}

$model = A shell getprop ro.product.model
$rel = A shell getprop ro.build.version.release
$sdkv = A shell getprop ro.build.version.sdk
$size = A shell wm size
$density = A shell wm density
Write-Host "device: $model  Android $rel (API $sdkv)  $size  $density"
Write-Host ''

$apkPath = Join-Path $root $Apk
if (-not (Test-Path $apkPath)) { Write-Host "APK not found: $apkPath"; exit 2 }

# --- identity of the APK itself ---------------------------------------------
$aapt2 = Get-Aapt2
if ($aapt2) {
    $badging = (& $aapt2 dump badging $apkPath 2>&1 | Out-String)
    Check 'APK is the expected package' ($badging -match "package: name='$pkg'") $pkg
    Check 'APK is arm64' ($badging -match "native-code: 'arm64-v8a'") 'arm64-v8a'
}

# --- install and launch ------------------------------------------------------
$install = A install -r $apkPath
Check 'installs on the device' ($install -match 'Success') ($install -split "`n" | Select-Object -Last 1)

& $adb @dev logcat -c 2>&1 | Out-Null
A shell am force-stop $pkg | Out-Null
A shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 | Out-Null

# cold start can be slow on a real phone too; poll rather than sleep
$home = Shot 'd01-launch'
$lit = Lit $home
$waited = 10
while ($lit -lt 0.05 -and $waited -lt 60) {
    Start-Sleep -Seconds 5; $waited += 5
    $home = Shot 'd01-launch'; $lit = Lit $home
}
Check 'renders a first frame' ($lit -ge 0.05) ("lit $lit after ${waited}s")

# --- THE question: which renderer actually ran -------------------------------
$log = & $adb @dev logcat -d 2>&1 | Out-String
$hasVulkan = $log -match 'Vulkan [0-9.]+ .*Forward Mobile'
$hasGL = $log -match 'OpenGL API OpenGL ES'
$presentErr = $log -match "Couldn't present to Vulkan queue"
Check 'renderer is Vulkan mobile' ($hasVulkan -and -not $hasGL) `
    $(if ($hasVulkan) { 'Vulkan Forward Mobile' } elseif ($hasGL) { 'FELL BACK to OpenGL ES' } else { 'no renderer line found' })
Check 'no Vulkan present failure' (-not $presentErr) $(if ($presentErr) { 'present to queue failed' } else { 'clean' })

$pid1 = A shell pidof $pkg
Check 'process stays alive' ($pid1 -ne '') "pid=$pid1"

# --- portrait lock -----------------------------------------------------------
A shell settings put system accelerometer_rotation 0 | Out-Null
A shell settings put system user_rotation 1 | Out-Null
Start-Sleep -Seconds 4
$rot = Shot 'd02-forced-landscape'
Add-Type -AssemblyName System.Drawing
try {
    $img = [System.Drawing.Image]::FromFile($rot)
    $portrait = $img.Height -gt $img.Width
    $dims = "$($img.Width)x$($img.Height)"
    $img.Dispose()
} catch { $portrait = $false; $dims = 'unreadable screenshot' }
Check 'stays portrait when rotated' $portrait $dims
A shell settings put system user_rotation 0 | Out-Null
A shell settings put system accelerometer_rotation 1 | Out-Null

# --- game path: home -> levels -> level 1 -> pour ---------------------------
A shell input tap 540 1336 | Out-Null
Start-Sleep -Seconds 4
$after = Shot 'd03-levels-or-game'
$changed = 0.0
try {
    $d = & py -3.12 (Join-Path $PSScriptRoot 'png_stats.py') diff $home $after 2>&1 | Out-String
    if ($d -match 'changed=([0-9.]+)') { $changed = [double]$Matches[1] }
} catch { }
Check 'touch reaches the game' ($changed -ge 0.01) "changed fraction $changed"

# --- stability ---------------------------------------------------------------
$crash = $log -match 'FATAL EXCEPTION|signal 11'
Check 'no fatal crash during launch' (-not $crash) $(if ($crash) { 'fatal logged' } else { 'clean' })

# --- force stop and relaunch -------------------------------------------------
A shell am force-stop $pkg | Out-Null
Start-Sleep -Seconds 2
A shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 10
$re = Shot 'd04-relaunch'
$relit = Lit $re
Check 'relaunches and renders' (($relit -ge 0.05) -and ((A shell pidof $pkg) -ne '')) "lit=$relit"

# --- verdict -----------------------------------------------------------------
$verdict = if ($failures -eq 0) { "ALL $($results.Count) CHECKS PASSED" } else { "$failures CHECK(S) FAILED" }
$report = @(
    '# Physical device pass'
    ''
    "**When:** $((Get-Date).ToString('yyyy-MM-dd HH:mm'))  "
    "**Device:** $model, Android $rel (API $sdkv), $size, $density  "
    "**APK:** $Apk  "
    "**Result:** $verdict"
    ''
    '| Check | Result | Detail |'
    '|---|---|---|'
) + $results + @(
    ''
    'Screenshots are in this folder. This covers the automated rows only; the'
    'remaining device-validation rows (audio, thermals, frame timing, launcher'
    'icon, multi-tube boards) still need a human holding the phone.'
)
Set-Content -Path (Join-Path $outDir 'report.md') -Value ($report -join "`n")
& $adb @dev logcat -d > (Join-Path $outDir 'logcat.txt') 2>&1

Write-Host ''
if ($failures -eq 0) { Write-Host "DEVICE PASS OK  (report: builds\device-pass\report.md)" }
else { Write-Host "DEVICE PASS FAILED: $failures check(s)" }
exit ([Math]::Min($failures, 125))
