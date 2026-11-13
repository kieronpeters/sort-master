# Runs the full automated suite: rules + validation + layout + progress,
# solver parity, and the 30-level integration flow.
# Usage: powershell -ExecutionPolicy Bypass -File tools\test.ps1
# Exit code 0 only when every suite passes.

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$godot = 'C:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$project = Join-Path $root 'godot'
$outDir = Join-Path $root 'builds'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

if (-not (Test-Path $godot)) { Write-Error "Godot not found at $godot"; exit 2 }

$suites = @(
    @{ Name = 'rules'; Script = 'test_rules'; Timeout = 180000 },
    @{ Name = 'parity'; Script = 'parity'; Timeout = 180000 },
    @{ Name = 'flow'; Script = 'test_flow'; Timeout = 300000 }
)

$failures = 0
foreach ($suite in $suites) {
    $log = Join-Path $outDir ("test-" + $suite.Name + ".log")
    $err = "$log.err"
    $p = Start-Process -FilePath $godot `
        -ArgumentList '--headless', '--path', $project, '--script', ("res://tests/" + $suite.Script + ".gd") `
        -RedirectStandardOutput $log -RedirectStandardError $err `
        -PassThru -NoNewWindow
    $null = $p.WaitForExit($suite.Timeout)
    $p.Refresh()

    $summary = Get-Content $log -ErrorAction SilentlyContinue | Where-Object { $_ -match 'PASSED|FAILED' } | Select-Object -Last 1
    $bad = Get-Content $err -ErrorAction SilentlyContinue | Where-Object { $_ -match '^FAIL:' }

    $ok = ($null -ne $summary) -and ($summary -match 'FAILED: 0') -and ($bad.Count -eq 0) -and ($p.ExitCode -ne 1)
    if ($ok) {
        Write-Host ("PASS  {0,-7} {1}" -f $suite.Name, $summary)
    } else {
        $failures += 1
        Write-Host ("FAIL  {0,-7} {1}" -f $suite.Name, $summary)
        $bad | Select-Object -First 10 | ForEach-Object { Write-Host ("      " + $_) }
    }
}

if ($failures -gt 0) {
    Write-Host "$failures suite(s) failed"
    exit 1
}
Write-Host 'ALL SUITES PASSED'
exit 0
