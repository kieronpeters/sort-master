# Generates the six in-liquid symbol icons (BUG-04).
# Original artwork, drawn here so the project owns every pixel.
Add-Type -AssemblyName System.Drawing

$outDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'godot\assets\2d\glyphs'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$size = 128
$white = [System.Drawing.Color]::White

function New-Canvas {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    return @($bmp, $g)
}

function Save-Canvas($bmp, $g, $name) {
    $bmp.Save((Join-Path $outDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

function New-Brush {
    return New-Object System.Drawing.SolidBrush($white)
}

# A - droplet
$c = New-Canvas; $b = New-Brush
$c[1].FillEllipse($b, 24, 46, 80, 76)
$tri = @(
    (New-Object System.Drawing.PointF(64, 6)),
    (New-Object System.Drawing.PointF(22, 72)),
    (New-Object System.Drawing.PointF(106, 72))
)
$c[1].FillPolygon($b, [System.Drawing.PointF[]]$tri)
$b.Dispose(); Save-Canvas $c[0] $c[1] 'glyph_a.png'

# B - prism / diamond
$c = New-Canvas; $b = New-Brush
$pts = @(
    (New-Object System.Drawing.PointF(64, 4)),
    (New-Object System.Drawing.PointF(120, 64)),
    (New-Object System.Drawing.PointF(64, 124)),
    (New-Object System.Drawing.PointF(8, 64))
)
$c[1].FillPolygon($b, [System.Drawing.PointF[]]$pts)
$b.Dispose(); Save-Canvas $c[0] $c[1] 'glyph_b.png'

# C - triangle (distinct from the droplet at small sizes)
$c = New-Canvas; $b = New-Brush
$pts = @(
    (New-Object System.Drawing.PointF(64, 8)),
    (New-Object System.Drawing.PointF(120, 116)),
    (New-Object System.Drawing.PointF(8, 116))
)
$c[1].FillPolygon($b, [System.Drawing.PointF[]]$pts)
$b.Dispose(); Save-Canvas $c[0] $c[1] 'glyph_c.png'

# D - four point sparkle
$c = New-Canvas; $b = New-Brush
$pts = @(
    (New-Object System.Drawing.PointF(64, 2)),
    (New-Object System.Drawing.PointF(78, 50)),
    (New-Object System.Drawing.PointF(126, 64)),
    (New-Object System.Drawing.PointF(78, 78)),
    (New-Object System.Drawing.PointF(64, 126)),
    (New-Object System.Drawing.PointF(50, 78)),
    (New-Object System.Drawing.PointF(2, 64)),
    (New-Object System.Drawing.PointF(50, 50))
)
$c[1].FillPolygon($b, [System.Drawing.PointF[]]$pts)
$b.Dispose(); Save-Canvas $c[0] $c[1] 'glyph_d.png'

# E - hexagon
$c = New-Canvas; $b = New-Brush
$pts = @()
for ($i = 0; $i -lt 6; $i++) {
    $a = [math]::PI / 3.0 * $i - [math]::PI / 2.0
    $pts += New-Object System.Drawing.PointF((64 + 58 * [math]::Cos($a)), (64 + 58 * [math]::Sin($a)))
}
$c[1].FillPolygon($b, [System.Drawing.PointF[]]$pts)
$b.Dispose(); Save-Canvas $c[0] $c[1] 'glyph_e.png'

# F - ring
$c = New-Canvas
$pen = New-Object System.Drawing.Pen($white, 22)
$c[1].DrawEllipse($pen, 20, 20, 88, 88)
$pen.Dispose(); Save-Canvas $c[0] $c[1] 'glyph_f.png'

Get-ChildItem $outDir -Filter 'glyph_*.png' | Select-Object Name, Length | Format-Table -AutoSize
