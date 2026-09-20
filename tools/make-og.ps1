# Generates the Open Graph / social card for aaronstalberg.com
# 1200x630 (LinkedIn / Facebook / X summary_large_image standard)
# Run:  pwsh -File tools\make-og.ps1
Add-Type -AssemblyName System.Drawing

$outDir = Split-Path -Parent $PSScriptRoot
$W = 1200; $H = 630

$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

# ---- background: deep navy gradient -------------------------------------
$rect = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(255, 14, 22, 38),
    [System.Drawing.Color]::FromArgb(255, 27, 62, 101),
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal)
$g.FillRectangle($bg, $rect)

# ---- soft radial glow, top-right ----------------------------------------
$glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$glowPath.AddEllipse(880, -230, 620, 620)
$glow = New-Object System.Drawing.Drawing2D.PathGradientBrush($glowPath)
$glow.CenterColor = [System.Drawing.Color]::FromArgb(70, 90, 160, 226)
$glow.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 20, 40, 70))
$g.FillPath($glow, $glowPath)

# ---- hairline accent bar down the left ---------------------------------
$accent = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 122, 176, 226))
$g.FillRectangle($accent, 0, 0, 10, $H)

# ---- monogram tile ------------------------------------------------------
$tile = New-Object System.Drawing.Rectangle(90, 96, 132, 132)
$tileBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $tile,
    [System.Drawing.Color]::FromArgb(255, 47, 105, 163),
    [System.Drawing.Color]::FromArgb(255, 31, 78, 121),
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal)
$g.FillRectangle($tileBrush, $tile)

$mono = New-Object System.Drawing.Font("Segoe UI", 52, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center
$g.DrawString("AS", $mono, $white, (New-Object System.Drawing.RectangleF(90, 96, 132, 126)), $sf)

# ---- name ---------------------------------------------------------------
$nameFont = New-Object System.Drawing.Font("Segoe UI", 74, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$inkWhite = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 245, 248, 252))
$g.DrawString("Aaron Stalberg", $nameFont, $inkWhite, 92, 262)

# ---- rule ---------------------------------------------------------------
$ruleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 122, 176, 226))
$g.FillRectangle($ruleBrush, 96, 398, 150, 4)

# ---- strapline ----------------------------------------------------------
$subFont = New-Object System.Drawing.Font("Segoe UI", 33, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$subSoft = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 186, 205, 226))
$g.DrawString("AI tools, automation and AI search visibility", $subFont, $subSoft, 92, 442)

# ---- domain -------------------------------------------------------------
$domFont = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$domSoft = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 122, 176, 226))
$g.DrawString("aaronstalberg.com", $domFont, $domSoft, 94, 512)

# ---- save ---------------------------------------------------------------
$png = Join-Path $outDir "og-card.png"
$jpg = Join-Path $outDir "og-card.jpg"
$bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)

# JPEG at high quality for platforms that prefer it
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 92L)
$bmp.Save($jpg, $codec, $ep)

$g.Dispose(); $bmp.Dispose()
"WROTE: $png ({0:N0} bytes)" -f (Get-Item $png).Length
"WROTE: $jpg ({0:N0} bytes)" -f (Get-Item $jpg).Length
