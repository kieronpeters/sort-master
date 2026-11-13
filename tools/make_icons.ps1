# Generates the launcher icon and the two Android adaptive layers.
# Original artwork; no third-party imagery. Output: godot/assets/2d/icons/.
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'godot\assets\2d\icons'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function Draw-Icon([int]$size, [string]$file, [bool]$withBg) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    $u = [double]$size / 512.0

    if ($withBg) {
        $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
        $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb(255, 16, 46, 60), [System.Drawing.Color]::FromArgb(255, 6, 17, 22), 90)
        $g.FillRectangle($br, $rect)
        $br.Dispose()
    }

    # neck
    $neck = New-Object System.Drawing.RectangleF((218*$u), (128*$u), (76*$u), (48*$u))
    $neckPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 205, 240, 250), [float](9*$u))
    $g.DrawRectangle($neckPen, $neck.X, $neck.Y, $neck.Width, $neck.Height)

    # body (rounded rect)
    $body = New-Object System.Drawing.RectangleF((146*$u), (170*$u), (220*$u), (230*$u))
    $bodyPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = [float](54*$u)
    $bodyPath.AddArc($body.X, $body.Y, $r, $r, 180, 90)
    $bodyPath.AddArc($body.Right - $r, $body.Y, $r, $r, 270, 90)
    $bodyPath.AddArc($body.Right - $r, $body.Bottom - $r, $r, $r, 0, 90)
    $bodyPath.AddArc($body.X, $body.Bottom - $r, $r, $r, 90, 90)
    $bodyPath.CloseFigure()

    $glassFill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80, 175, 225, 240))
    $g.FillPath($glassFill, $bodyPath)

    # liquid bands, clipped to the body
    $g.SetClip($bodyPath)
    $cols = @(
        [System.Drawing.Color]::FromArgb(255, 47, 164, 95),
        [System.Drawing.Color]::FromArgb(255, 255, 194, 75),
        [System.Drawing.Color]::FromArgb(255, 70, 216, 208)
    )
    $bh = 230.0 / 4.0
    for ($i = 0; $i -lt 3; $i++) {
        $b = New-Object System.Drawing.SolidBrush($cols[$i])
        $rr = New-Object System.Drawing.RectangleF((146*$u), ((170 + $bh * (2 - $i)) * $u), (220*$u), ($bh*$u))
        $g.FillRectangle($b, $rr)
        $b.Dispose()
    }
    $g.ResetClip()

    $g.DrawPath($neckPen, $bodyPath)

    # highlight
    $hl = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(170, 255, 255, 255), [float](7*$u))
    $g.DrawLine($hl, [float](178*$u), [float](205*$u), [float](178*$u), [float](365*$u))

    $hl.Dispose(); $neckPen.Dispose(); $glassFill.Dispose(); $bodyPath.Dispose()
    $bmp.Save((Join-Path $outDir $file), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

function Draw-Background([int]$size, [string]$file) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb(255, 18, 52, 63), [System.Drawing.Color]::FromArgb(255, 6, 17, 22), 90)
    $g.FillRectangle($br, $rect)
    $br.Dispose()
    # soft prism glow, no bottle: the foreground layer carries the mark
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse(0, 0, $size, $size)
    $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $pgb.CenterColor = [System.Drawing.Color]::FromArgb(255, 24, 74, 84)
    $pgb.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(255, 6, 17, 22))
    $g.FillPath($pgb, $path)
    $pgb.Dispose(); $path.Dispose()
    $bmp.Save((Join-Path $outDir $file), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}
Draw-Icon 512 'icon.png' $true
Draw-Icon 432 'icon_foreground.png' $false
Draw-Background 432 'icon_background.png'

Get-ChildItem $outDir -Filter 'icon*.png' | Select-Object Name, Length | Format-Table -AutoSize
