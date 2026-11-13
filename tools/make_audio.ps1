# Synthesises the game's sound effects.
# Every sample is generated from scratch here: no third-party audio, no
# unclear licences. Output is 22.05 kHz 16-bit mono WAV, which is plenty for
# short UI sounds and keeps the APK small.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$outDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'godot\assets\audio'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$rate = 22050

function Write-Wav([string]$name, [double[]]$samples) {
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
    $bw.Write([int](36 + $samples.Count * 2))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('WAVE'))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('fmt '))
    $bw.Write([int]16)
    $bw.Write([int16]1)
    $bw.Write([int16]1)
    $bw.Write([int]$rate)
    $bw.Write([int]($rate * 2))
    $bw.Write([int16]2)
    $bw.Write([int16]16)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
    $bw.Write([int]($samples.Count * 2))
    foreach ($s in $samples) {
        $v = [math]::Max(-1.0, [math]::Min(1.0, $s))
        $bw.Write([int16]($v * 30000))
    }
    $bw.Flush()
    [System.IO.File]::WriteAllBytes((Join-Path $outDir $name), $ms.ToArray())
    $bw.Dispose(); $ms.Dispose()
}

function Samples([double]$seconds) { return [int]($seconds * $rate) }

function Envelope([double]$t, [double]$attack, [double]$decay) {
    if ($t -lt $attack) { return $t / $attack }
    return [math]::Exp(-($t - $attack) / $decay)
}

# --- selection: a soft glassy tick -----------------------------------------
$n = Samples 0.09
$data = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $rate
    $e = Envelope $t 0.004 0.022
    $data[$i] = 0.22 * $e * ([math]::Sin(2 * [math]::PI * 880 * $t) + 0.45 * [math]::Sin(2 * [math]::PI * 1320 * $t))
}
Write-Wav 'select.wav' $data

# --- pour: a short rising liquid sweep -------------------------------------
$n = Samples 0.22
$data = New-Object double[] $n
$phase = 0.0
for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $rate
    $f = 220 + 380 * ($t / 0.22)
    $phase += 2 * [math]::PI * $f / $rate
    $e = Envelope $t 0.012 0.075
    $air = (Get-Random -Minimum -1.0 -Maximum 1.0) * 0.05 * $e
    $data[$i] = 0.20 * $e * ([math]::Sin($phase) + 0.30 * [math]::Sin(2 * $phase)) + $air
}
Write-Wav 'pour.wav' $data

# --- invalid: a muted low thud ---------------------------------------------
$n = Samples 0.16
$data = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $rate
    $e = Envelope $t 0.005 0.045
    $data[$i] = 0.26 * $e * ([math]::Sin(2 * [math]::PI * 150 * $t) + 0.5 * [math]::Sin(2 * [math]::PI * 96 * $t))
}
Write-Wav 'invalid.wav' $data

# --- undo: a soft descending blip ------------------------------------------
$n = Samples 0.14
$data = New-Object double[] $n
$phase = 0.0
for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $rate
    $f = 620 - 260 * ($t / 0.14)
    $phase += 2 * [math]::PI * $f / $rate
    $e = Envelope $t 0.006 0.05
    $data[$i] = 0.18 * $e * [math]::Sin($phase)
}
Write-Wav 'undo.wav' $data

# --- win: a warm four-note arpeggio ----------------------------------------
$n = Samples 0.85
$data = New-Object double[] $n
$notes = @(523.25, 659.25, 783.99, 1046.50)
for ($k = 0; $k -lt 4; $k++) {
    $start = [int]($k * 0.11 * $rate)
    for ($i = $start; $i -lt $n; $i++) {
        $t = ($i - $start) / $rate
        $e = Envelope $t 0.01 0.20
        $data[$i] += 0.14 * $e * ([math]::Sin(2 * [math]::PI * $notes[$k] * $t) + 0.25 * [math]::Sin(4 * [math]::PI * $notes[$k] * $t))
    }
}
Write-Wav 'win.wav' $data

# --- ui: a neutral click ---------------------------------------------------
$n = Samples 0.05
$data = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $rate
    $e = Envelope $t 0.002 0.012
    $data[$i] = 0.16 * $e * [math]::Sin(2 * [math]::PI * 440 * $t)
}
Write-Wav 'ui.wav' $data

Get-ChildItem $outDir -Filter '*.wav' | Select-Object Name, Length | Format-Table -AutoSize
