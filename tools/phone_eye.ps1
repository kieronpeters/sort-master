# phone_eye.ps1 - a local "always-available eye" on the ADB-connected phone.
#
# Why this exists: no DSH plugin provides continuous Android screen capture (the
# only candidate, dsh-cua-bundle, reports unsupported-platform here, and REA's
# capture_adb_screen is a single shot). This does NOT give the model a video
# stream - the model only ever sees an image when a tool call returns one. What
# it does give is the two things that actually cost round trips:
#
#   * a frame that is always ready on disk, so a look is a read not a capture
#   * wait-for-stable, so "has the animation finished" is one blocking call
#
# Usage:
#   .\phone_eye.ps1 latest              # capture now, print path+hash
#   .\phone_eye.ps1 stable -ms 500      # block until nothing changes for 500ms
#   .\phone_eye.ps1 change -timeout 20  # block until the screen changes
#   .\phone_eye.ps1 monitor             # background: keep latest.png fresh

param(
    [Parameter(Position = 0)][string]$Command = "latest",
    [int]$Ms = 500,
    [int]$Timeout = 30,
    [int]$Poll = 200
)

$ErrorActionPreference = 'Continue'
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$dir = Join-Path $PSScriptRoot '..\builds\eye'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$latest = Join-Path $dir 'latest.png'
$stamped = Join-Path $dir 'last-change.png'

function Grab([string]$path) {
    $tmp = "$path.tmp"
    # exec-out keeps the PNG binary intact; PowerShell's own '>' would corrupt it
    & cmd /c "`"$adb`" exec-out screencap -p > `"$tmp`"" 2>$null
    if ((Test-Path $tmp) -and ((Get-Item $tmp).Length -gt 2000)) {
        Move-Item -Force $tmp $path
        return (Get-FileHash $path -Algorithm SHA256).Hash
    }
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    return $null
}

# Exact hashes are useless on a phone whose background animates every frame: the
# game board has twinkling particles, so two identical-looking frames never share
# a hash. Compare a 64x128 downscale instead and treat small differences as "the
# same screen".
Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
function Signature([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    try {
        $src = [System.Drawing.Image]::FromFile($path)
        $bmp = New-Object System.Drawing.Bitmap 64, 128
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.DrawImage($src, 0, 0, 64, 128)
        $g.Dispose(); $src.Dispose()
        $vals = New-Object 'System.Collections.Generic.List[int]'
        for ($y = 0; $y -lt 128; $y += 2) {
            for ($x = 0; $x -lt 64; $x += 2) {
                $p = $bmp.GetPixel($x, $y)
                $vals.Add([int](($p.R + $p.G + $p.B) / 3))
            }
        }
        $bmp.Dispose()
        return ,$vals.ToArray()
    } catch { return $null }
}

function Difference($a, $b) {
    if ($a -eq $null -or $b -eq $null) { return 100.0 }
    $n = [Math]::Min($a.Count, $b.Count)
    if ($n -eq 0) { return 100.0 }
    $changed = 0
    for ($i = 0; $i -lt $n; $i++) {
        if ([Math]::Abs($a[$i] - $b[$i]) -gt 10) { $changed++ }
    }
    return (100.0 * $changed / $n)
}

function Describe([string]$hash) {
    if (-not $hash) { return "no frame" }
    return "hash=$($hash.Substring(0,12)) bytes=$((Get-Item $latest).Length)"
}

switch ($Command) {
    'latest' {
        $h = Grab $latest
        Write-Output "latest $h"
        Write-Output (Describe $h)
    }
    'stable' {
        # Returns as soon as the screen has not changed for $Ms. This is the
        # "animation finished" primitive: no polling from the caller.
        $prev = Signature $latest; Grab $latest | Out-Null; $prev = Signature $latest
        $steadySince = Get-Date
        $deadline = (Get-Date).AddSeconds($Timeout)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds $Poll
            Grab $latest | Out-Null
            $now = Signature $latest
            $d = Difference $prev $now
            if ($d -gt 12.0) {
                $prev = $now
                $steadySince = Get-Date
            }
            elseif (((Get-Date) - $steadySince).TotalMilliseconds -ge $Ms) {
                Write-Output ("stable after {0}ms steady (last diff {1:N1}%)" -f [int]((Get-Date) - $steadySince).TotalMilliseconds, $d)
                if (Test-Path $latest) { Copy-Item -Force $latest $stamped }
                return
            }
        }
        Write-Output "stable TIMEOUT (still changing after ${Timeout}s)"
    }
    'change' {
        Grab $latest | Out-Null
        $start = Signature $latest
        $deadline = (Get-Date).AddSeconds($Timeout)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds $Poll
            Grab $latest | Out-Null
            $now = Signature $latest
            $d = Difference $start $now
            if ($d -gt 15.0) {
                Write-Output ("changed (diff {0:N1}%)" -f $d)
                if (Test-Path $latest) { Copy-Item -Force $latest $stamped }
                return
            }
        }
        Write-Output "changed NONE within ${Timeout}s (screen is static)"
    }
    'monitor' {
        # Keeps latest.png fresh so a look is a file read rather than a capture.
        # Prints a line whenever the screen changes, so a background job carries
        # an activity log the model can read cheaply as text.
        $prev = $null
        while ($true) {
            $h = Grab $latest
            if ($h -and $h -ne $prev) {
                $ts = (Get-Date).ToString('HH:mm:ss')
                Write-Output "$ts CHANGE $($h.Substring(0,12))"
                Copy-Item -Force $latest $stamped
                $prev = $h
            }
            Start-Sleep -Milliseconds $Poll
        }
    }
    default { Write-Output "unknown command: $Command" }
}
