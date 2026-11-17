# Runs the full automated suite:
#   rules + validation + layout + save   (test_rules.gd)
#   solver -> game parity                (parity.gd)
#   game -> solver parity + 30-level flow (test_flow.gd + verify_game_moves.py)
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\test.ps1
# Exit code 0 only when every suite passes.

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_build_lib.ps1')
Initialize-GodotUserData | Out-Null

$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root 'godot'
$outDir = Join-Path $root 'builds'
$godot = Resolve-Godot
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$failures = 0
$transcript = Join-Path $outDir 'game_moves.json'
if (Test-Path $transcript) { Remove-Item $transcript -Force }

function Invoke-GodotSuite([string]$name, [string]$script, [string[]]$extraArgs = @()) {
    $log = Join-Path $outDir ("test-" + $name + ".log")
    $callArgs = @('--headless', '--path', $project, '--script', ("res://tests/" + $script + ".gd"))
    if ($extraArgs.Count -gt 0) { $callArgs += @('--') + $extraArgs }
    $ErrorActionPreference = 'Continue'
    $output = & $godot @callArgs 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $output | Set-Content -Path $log
    $summary = $output | Where-Object { $_ -match 'PASSED|FAILED' } | Select-Object -Last 1
    $bad = @($output | Where-Object { $_ -match '^FAIL:' })
    if ($code -eq 0 -and $summary -match 'FAILED: 0' -and $bad.Count -eq 0) {
        Write-Host ("PASS  {0,-7} {1}" -f $name, $summary)
        return $true
    }
    Write-Host ("FAIL  {0,-7} {1}" -f $name, $summary)
    $bad | Select-Object -First 10 | ForEach-Object { Write-Host ("      " + $_) }
    return $false
}

if (-not (Invoke-GodotSuite 'rules' 'test_rules')) { $failures += 1 }
if (-not (Invoke-GodotSuite 'parity' 'parity')) { $failures += 1 }
if (-not (Invoke-GodotSuite 'flow' 'test_flow' @("--transcript=$transcript"))) { $failures += 1 }

# Direction 2: the independent Python rules replay the game's recorded moves.
$verifyLog = Join-Path $outDir 'test-game-moves.log'
$ErrorActionPreference = 'Continue'
$verifyOutput = & py -3.12 (Join-Path $root 'tools\solver\verify_game_moves.py') --transcript $transcript --levels (Join-Path $project 'levels') 2>&1
$verifyCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
$verifyOutput | Set-Content -Path $verifyLog
$verifySummary = $verifyOutput | Where-Object { $_ -match 'GAME MOVES VERIFIED' } | Select-Object -Last 1
if ($verifyCode -eq 0 -and $verifySummary -match 'FAILED: 0') {
    Write-Host ("PASS  {0,-7} {1}" -f 'moves', $verifySummary)
} else {
    $failures += 1
    Write-Host ("FAIL  {0,-7} {1}" -f 'moves', $verifySummary)
    $verifyOutput | Select-Object -First 10 | ForEach-Object { Write-Host ("      " + $_) }
}

if ($failures -gt 0) {
    Write-Host "$failures suite(s) failed"
    exit 1
}
Write-Host 'ALL SUITES PASSED'
exit 0
