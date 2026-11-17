# Shared helpers for the build and test scripts.
# No credentials and no personal paths: the Godot binary can always be
# overridden with $env:GODOT or a binary on PATH.

function Initialize-GodotUserData {
    # Godot resolves user:// (progress saves, logs, editor settings) under
    # %APPDATA%\Godot on Windows. A sandboxed or locked-down workspace can make
    # that path read-only; every save test then reports a false failure and the
    # test script aborts before it can quit. Probe it once and, only when it is
    # not writable, point APPDATA at a git-ignored directory inside the repo for
    # this process. The assertions themselves are unchanged.
    $root = Split-Path -Parent $PSScriptRoot
    $writable = $false
    try {
        $base = Join-Path $env:APPDATA 'Godot'
        New-Item -ItemType Directory -Path $base -Force -ErrorAction Stop | Out-Null
        $probe = Join-Path $base ('.probe-' + [guid]::NewGuid().ToString('N'))
        Set-Content -LiteralPath $probe -Value 'x' -ErrorAction Stop
        Remove-Item -LiteralPath $probe -Force -ErrorAction Stop
        $writable = $true
    } catch {
        $writable = $false
    }
    if ($writable) { return $null }
    $local = Join-Path $root '.localdata'
    New-Item -ItemType Directory -Path $local -Force | Out-Null
    $env:APPDATA = $local
    Write-Host "note: %APPDATA%\Godot is not writable; using $local for user:// data"
    return $local
}

function Resolve-Godot {
    $candidates = @()
    if ($env:GODOT) { $candidates += $env:GODOT }
    $candidates += 'C:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $candidates += $cmd.Source }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    throw "Godot not found. Set `$env:GODOT to the console executable."
}

function Get-Aapt2 {
    $base = Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools'
    if (Test-Path $base) {
        foreach ($dir in (Get-ChildItem $base -Directory | Sort-Object Name -Descending)) {
            $path = Join-Path $dir.FullName 'aapt2.exe'
            if (Test-Path $path) { return $path }
        }
    }
    return $null
}

function Get-ApkSigner {
    $base = Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools'
    if (Test-Path $base) {
        foreach ($dir in (Get-ChildItem $base -Directory | Sort-Object Name -Descending)) {
            $path = Join-Path $dir.FullName 'apksigner.bat'
            if (Test-Path $path) { return $path }
        }
    }
    return $null
}

function Test-ApkSigned([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }
    $signer = Get-ApkSigner
    if ($signer) {
        $ErrorActionPreference = 'Continue'
        & $signer verify $Path 2>$null | Out-Null
        $ok = $LASTEXITCODE -eq 0
        $ErrorActionPreference = 'Stop'
        return $ok
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    $found = @($zip.Entries | Where-Object { $_.FullName -match '^META-INF/.*\.(RSA|DSA|EC)$' }).Count -gt 0
    $zip.Dispose()
    return $found
}

function Get-ApkDebuggable([string]$Path) {
    $aapt2 = Get-Aapt2
    if (-not $aapt2) { return $null }
    $ErrorActionPreference = 'Continue'
    $tree = (& $aapt2 dump xmltree --file AndroidManifest.xml $Path 2>&1 | Out-String)
    $ErrorActionPreference = 'Stop'
    return ($tree -match 'debuggable\(0x0101000f\)=(true|0xffffffff)')
}

function Assert-Apk([string]$Path, [int]$VersionCode, [switch]$RequirePortrait) {
    if (-not (Test-Path $Path)) { throw "APK not found: $Path" }
    $aapt2 = Get-Aapt2
    if (-not $aapt2) {
        if ($RequirePortrait) { throw 'aapt2 not found: cannot verify the release APK' }
        Write-Host 'aapt2 not found - skipping APK identity assertions'
        return
    }
    $ErrorActionPreference = 'Continue'
    $badging = (& $aapt2 dump badging $Path 2>&1 | Out-String)
    $ErrorActionPreference = 'Stop'
    if ($badging -notmatch "package: name='com.prismgarden.sortmaster'") { throw 'APK package id is wrong' }
    if ($badging -notmatch "versionCode='$VersionCode'") { throw "APK version code is not $VersionCode" }
    if ($RequirePortrait) {
        $ErrorActionPreference = 'Continue'
        $tree = (& $aapt2 dump xmltree --file AndroidManifest.xml $Path 2>&1 | Out-String)
        $ErrorActionPreference = 'Stop'
        if ($tree -notmatch 'screenOrientation\(0x0101001e\)=1') {
            throw 'APK is not portrait-locked (screenOrientation != 1)'
        }
    }
}
