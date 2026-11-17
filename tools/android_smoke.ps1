# Android smoke harness for Sort Master.
#
# One command that boots the emulator, installs the build, proves it renders and
# responds, and writes a report. It exists so the next cycle costs a command
# instead of an hour of driving taps by hand.
#
# It fails closed: if the run ends early for any reason, the report says how many
# checks actually ran and exits non-zero. A green report from a half-finished run
# is worse than no harness.
#
# Asserts: installs; process alive; foreground; first frame not blank; a tap
# changes the screen; second screen renders; no fatal crash; stays portrait when
# the system is forced to landscape; relaunches after a force stop.
#
# Does NOT judge play correctness, audio, frame timing or thermals. It is a smoke
# test, not the S23 Ultra pass in docs/device-validation.md.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools\android_smoke.ps1
#   powershell -ExecutionPolicy Bypass -File tools\android_smoke.ps1 -Build
#   powershell -ExecutionPolicy Bypass -File tools\android_smoke.ps1 -Apk <path> -KeepRunning

param(
    [string]$Apk = "builds\sort-master.apk",
    [switch]$Build,
    [switch]$KeepRunning,
    [string]$Avd = "sm_test",
    [int]$BootTimeoutSeconds = 180
)

# adb and py write progress to stderr. Under 'Stop' that becomes a terminating
# error and kills the run, so this harness reports per check instead of throwing.
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '_build_lib.ps1')

$root = Split-Path -Parent $PSScriptRoot
$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emu = Join-Path $sdk 'emulator\emulator.exe'
$outDir = Join-Path $root 'builds\android-smoke'
$pkg = 'com.prismgarden.sortmaster'

if (-not (Test-Path $adb)) { Write-Host "adb not found at $adb"; exit 2 }
if (-not (Test-Path $emu)) { Write-Host "emulator not found at $emu"; exit 2 }

New-Item -ItemType Directory -Path $outDir -Force | Out-Null
Get-ChildItem $outDir -Filter '*.png' -ErrorAction SilentlyContinue | Remove-Item -Force

$results = New-Object System.Collections.Generic.List[string]
$failures = 0
$expectedChecks = 9
$aborted = $null

function Check {
    param([string]$name, [bool]$ok, [string]$detail)
    if ($ok) { Write-Host ("PASS  {0,-32} {1}" -f $name, $detail) }
    else { Write-Host ("FAIL  {0,-32} {1}" -f $name, $detail); $script:failures++ }
    $verdict = if ($ok) { 'PASS' } else { 'FAIL' }
    $script:results.Add("| $name | $verdict | $detail |")
}


function Shot {
    param([string]$name)
    $local = Join-Path $outDir "$name.png"
    & $adb shell screencap -p /sdcard/smoke.png 2>&1 | Out-Null
    & $adb pull /sdcard/smoke.png $local 2>&1 | Out-Null
    return $local
}

function Stat {
    param([string]$mode, [string[]]$files)
    $pyArgs = @((Join-Path $PSScriptRoot 'png_stats.py'), $mode) + $files
    $out = & py -3.12 @pyArgs 2>&1 | Out-String
    Write-Verbose $out
    if ($out -match 'lit=([0-9.]+)') { return [double]$Matches[1] }
    if ($out -match 'changed=([0-9.]+)') { return [double]$Matches[1] }
    Write-Host "  (png_stats returned: $($out.Trim()))"
    return -1
}

# --- optional build ----------------------------------------------------------
$apkPath = Join-Path $root $Apk
if ($Build) {
    # The game ships arm64-only; the emulator is x86_64. Flip the DEBUG preset
    # only, and always put it back.
    $cfg = Join-Path $root 'godot\export_presets.cfg'
    $original = Get-Content -LiteralPath $cfg -Raw
    try {
        $idx = $original.IndexOf('[preset.1]')
        $head = $original.Substring(0, $idx) -replace 'architectures/x86_64=false', 'architectures/x86_64=true'
        Set-Content -LiteralPath $cfg -Value ($head + $original.Substring($idx)) -NoNewline
        Write-Host 'building a dual-ABI debug APK for the emulator ...'
        & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build_debug.ps1') | Out-Null
    } finally {
        Set-Content -LiteralPath $cfg -Value $original -NoNewline
        Write-Host 'export preset restored to arm64-only'
    }
}

if (-not (Test-Path $apkPath)) { Write-Host "APK not found: $apkPath"; exit 2 }

# --- emulator ----------------------------------------------------------------
function Start-Emulator {
    Write-Host "starting emulator $Avd ..."
    # -feature -Vulkan: no emulator GPU backend on this host can present a Vulkan
    # swapchain, so the game only renders under the OpenGL compatibility
    # fallback. See docs/evidence/android/RESULTS.md.
    Start-Process -FilePath $emu -ArgumentList @(
        '-avd', $Avd, '-no-window', '-no-audio', '-no-boot-anim',
        '-gpu', 'host', '-no-snapshot', '-feature', '-Vulkan'
    ) -RedirectStandardOutput (Join-Path $outDir 'emulator.log') `
      -RedirectStandardError (Join-Path $outDir 'emulator.err.log') -WindowStyle Hidden
    & $adb wait-for-device 2>&1 | Out-Null
    $deadline = (Get-Date).AddSeconds($BootTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $b = (& $adb shell getprop sys.boot_completed 2>&1 | Out-String).Trim()
        if ($b -eq '1') { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

# --- run ---------------------------------------------------------------------
$startedEmulator = $false
try {
    & $adb devices 2>&1 | Out-Null
    $online = (& $adb devices 2>&1 | Select-String -Pattern "device$").Count -gt 0
    if (-not $online) {
        if (-not (Start-Emulator)) { Write-Host 'emulator did not boot'; exit 2 }
        $startedEmulator = $true
    }

    & $adb logcat -c 2>&1 | Out-Null

    $install = (& $adb install -r $apkPath 2>&1 | Out-String).Trim()
    Check 'installs' ($install -match 'Success') ($install -split "`n" | Select-Object -Last 1)

    & $adb shell am force-stop $pkg 2>&1 | Out-Null
    & $adb shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
    Start-Sleep -Seconds 15

    $appPid = (& $adb shell pidof $pkg 2>&1 | Out-String).Trim()
    Check 'process alive' ($appPid -ne '') "pid=$appPid"

    $focus = (& $adb shell dumpsys window 2>&1 | Select-String 'mCurrentFocus' | Select-Object -First 1).Line
    Check 'app is foreground' ("$focus" -match [regex]::Escape($pkg)) ("$focus".Trim())

    $homeShot = Shot 'home'
    $lit = Stat 'nonblack' @($homeShot)
    Check 'first frame is not blank' ($lit -ge 0.05) ("lit fraction $lit")

    # The primary button sits mid-screen, but its exact y depends on the saved
    # progress ("Begin" vs "Continue - Level N"), so try the primary then the
    # secondary before concluding that input is not reaching the game.
    $changed = 0.0
    $after = $null
    foreach ($y in @(1336, 1495)) {
        & $adb shell input tap 540 $y 2>&1 | Out-Null
        Start-Sleep -Seconds 4
        $after = Shot 'after-tap'
        $changed = Stat 'diff' @($homeShot, $after)
        if ($changed -ge 0.01) { break }
    }
    Check 'tap changes the screen' ($changed -ge 0.01) ("changed fraction $changed")

    $lit2 = Stat 'nonblack' @($after)
    Check 'second screen renders' ($lit2 -ge 0.05) ("lit fraction $lit2")

    $crashes = (& $adb logcat -d 2>&1 | Select-String -Pattern 'FATAL EXCEPTION|AndroidRuntime.*FATAL|signal 11').Count
    Check 'no fatal crash logged' ($crashes -eq 0) "fatal lines=$crashes"

    & $adb shell settings put system accelerometer_rotation 0 2>&1 | Out-Null
    & $adb shell settings put system user_rotation 1 2>&1 | Out-Null
    Start-Sleep -Seconds 4
    $rot = Shot 'forced-landscape'
    $dims = (& $adb shell wm size 2>&1 | Out-String).Trim()
    $shotDims = (& $adb shell dumpsys display 2>&1 | Select-String -Pattern 'mCurrentOrientation' | Select-Object -First 1).Line
    $isPortrait = $true
    try {
        Add-Type -AssemblyName System.Drawing
        $img = [System.Drawing.Image]::FromFile($rot)
        $isPortrait = $img.Height -gt $img.Width
        $dims = "$($img.Width)x$($img.Height)"
        $img.Dispose()
    } catch {
        $isPortrait = $false
        $dims = "could not read screenshot: $($_.Exception.Message)"
    }
    Check 'stays portrait when rotated' $isPortrait $dims
    & $adb shell settings put system user_rotation 0 2>&1 | Out-Null

    & $adb shell am force-stop $pkg 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    & $adb shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
    Start-Sleep -Seconds 14
    $appPid2 = (& $adb shell pidof $pkg 2>&1 | Out-String).Trim()
    $relaunch = Shot 'relaunch'
    $lit3 = Stat 'nonblack' @($relaunch)
    Check 'relaunches after force stop' (($appPid2 -ne '') -and ($lit3 -ge 0.05)) "pid=$appPid2 lit=$lit3"
} catch {
    $aborted = $_.Exception.Message
    Check 'run completed' $false ("aborted: " + $aborted)
} finally {
    if ($startedEmulator -and -not $KeepRunning) {
        & $adb emu kill 2>&1 | Out-Null
        Start-Sleep -Seconds 3
        Get-Process | Where-Object { $_.ProcessName -match 'qemu|emulator' } |
            Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host 'emulator stopped'
    }
}

# --- report ------------------------------------------------------------------
$ranAll = ($results.Count -ge $expectedChecks) -and ($null -eq $aborted)
if (-not $ranAll) { $failures = [Math]::Max($failures, 1) }

$verdict = if ($failures -eq 0 -and $ranAll) { "ALL $($results.Count) CHECKS PASSED" }
           else { "$failures CHECK(S) FAILED - $($results.Count) of $expectedChecks checks ran" }

$report = @(
    '# Android smoke run'
    ''
    "**When:** $((Get-Date).ToString('yyyy-MM-dd HH:mm'))  "
    "**APK:** $Apk  "
    "**AVD:** $Avd  "
    "**Result:** $verdict"
    ''
    '| Check | Result | Detail |'
    '|---|---|---|'
) + $results + @(
    ''
    'Screenshots land in this folder. Emulator logs: `emulator.log`, `emulator.err.log`.'
    ''
    'This is a smoke test. It does not judge play correctness, audio, frame timing'
    'or thermals, and it runs on the OpenGL compatibility fallback because no'
    'emulator GPU backend here can present a Vulkan swapchain. The shipped Vulkan'
    'renderer and the S23 Ultra rows in `docs/device-validation.md` remain untested.'
)
Set-Content -Path (Join-Path $outDir 'report.md') -Value ($report -join "`n")

Write-Host ''
if ($failures -eq 0 -and $ranAll) {
    Write-Host "ANDROID SMOKE OK  ($($results.Count) checks; report: builds\android-smoke\report.md)"
} else {
    Write-Host "ANDROID SMOKE FAILED: $verdict"
}
exit ([Math]::Min($failures, 125))
