Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Drawing.Common -ErrorAction SilentlyContinue

$bgPath = 'C:\Users\deero\.codex\generated_images\01a062bd-fb24-7e41-a440-16b5aba0e659\exec-bb9c284f-fa22-47ea-b7c1-5bc2f1c532c8.png'
$refPath = 'C:\Users\deero\.codex\skills\huhs-hardstyle-flyers\assets\reference-flyers\14-HSREVO_220528.jpg'
$huhsPath = 'C:\Users\deero\hungarian_hardstyle_app\assets\logos\huhs_logo.png'
$outPath = 'C:\Users\deero\hungarian_hardstyle_app\build\HUHS_Hardstyle_Revolution_2026-11-21_Facebook_v2.png'

$src = [System.Drawing.Bitmap]::new($bgPath)
$bmp = [System.Drawing.Bitmap]::new(1920,1080)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.DrawImage($src, [System.Drawing.Rectangle]::new(0,0,1920,1080))
$src.Dispose()

$ink = [System.Drawing.Color]::FromArgb(245,242,224)
$cyan = [System.Drawing.Color]::FromArgb(50,244,205)
$deep = [System.Drawing.Color]::FromArgb(5,14,17)
$muted = [System.Drawing.Color]::FromArgb(176,207,197)

# Crop the authentic Hardstyle Revolution logo from the supplied reference flyer.
$ref = [System.Drawing.Bitmap]::new($refPath)
$logoCrop = [System.Drawing.Bitmap]::new(210,110)
$lg = [System.Drawing.Graphics]::FromImage($logoCrop)
$lg.DrawImage($ref, [System.Drawing.Rectangle]::new(0,0,210,110), [System.Drawing.Rectangle]::new(1710,190,210,110), [System.Drawing.GraphicsUnit]::Pixel)
$lg.Dispose(); $ref.Dispose()
$g.DrawImage($logoCrop, [System.Drawing.Rectangle]::new(1665,60,185,97))
$logoCrop.Dispose()

# Safe-zone guide translated into a quiet footer rail.
$rail = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(205,3,12,15))
$g.FillRectangle($rail, 118, 884, 1684, 145); $rail.Dispose()
$line = [System.Drawing.Pen]::new($cyan, 3)
$g.DrawLine($line, 145, 884, 1775, 884); $line.Dispose()

$agency = New-Object System.Drawing.FontFamily('Agency FB')
$bah = New-Object System.Drawing.FontFamily('Bahnschrift')
$stencil = New-Object System.Drawing.FontFamily('Stencil')

function Draw-Centered($text, $font, $brush, $y, $width=1680, $x=120) {
  $size = $g.MeasureString($text, $font)
  $g.DrawString($text, $font, $brush, $x + (($width-$size.Width)/2), $y)
}
function Draw-Spaced($text, $font, $brush, $x, $y, $spacing) {
  $cursor = [double]$x
  foreach ($ch in $text.ToCharArray()) {
    $s = $ch.ToString(); $g.DrawString($s, $font, $brush, $cursor, $y)
    $cursor += $g.MeasureString($s, $font).Width + $spacing
  }
}

$fSmall = [System.Drawing.Font]::new($agency, 34, [System.Drawing.FontStyle]::Bold)
$fDate = [System.Drawing.Font]::new($stencil, 58, [System.Drawing.FontStyle]::Regular)
$fMonth = [System.Drawing.Font]::new($agency, 170, [System.Drawing.FontStyle]::Bold)
$fNumber = [System.Drawing.Font]::new($stencil, 260, [System.Drawing.FontStyle]::Bold)
$fLineup = [System.Drawing.Font]::new($agency, 32, [System.Drawing.FontStyle]::Bold)
$fFooter = [System.Drawing.Font]::new($agency, 24, [System.Drawing.FontStyle]::Bold)
$fHash = [System.Drawing.Font]::new($bah, 24, [System.Drawing.FontStyle]::Bold)

# Date anchor and typographic counterweight to the mandatory logo.
Draw-Spaced 'H A R D S T Y L E' $fSmall ([System.Drawing.SolidBrush]::new($cyan)) 155 205 12
Draw-Spaced '21' $fDate ([System.Drawing.SolidBrush]::new($ink)) 150 260 4
$g.DrawString('NOVEMBER', $fMonth, [System.Drawing.SolidBrush]::new($ink), 150, 370)
$g.DrawString('21', $fNumber, [System.Drawing.SolidBrush]::new($cyan), 1395, 305)

# Offset-registration treatment borrowed from the primary reference, applied to the date concept.
$off = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(180,50,244,205))
$g.DrawString('NOVEMBER', $fMonth, $off, 164, 380)
$g.DrawString('NOVEMBER', $fMonth, [System.Drawing.SolidBrush]::new($ink), 150, 370)

# Designed lineup block, kept inside the crop-safe central area.
$g.DrawString('LINE-UP', $fSmall, [System.Drawing.SolidBrush]::new($cyan), 155, 635)
$g.DrawString('DENOISER  |  SIDERUNNERS  |  ADAM BASS', $fLineup, [System.Drawing.SolidBrush]::new($ink), 155, 690)
$g.DrawString('IMPULZ  |  CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER', $fLineup, [System.Drawing.SolidBrush]::new($ink), 155, 745)

$g.DrawString('2026.11.21', $fDate, [System.Drawing.SolidBrush]::new($ink), 155, 910)
$g.DrawString('STENK  |  1087 BUDAPEST, KEREPESI ÚT', $fFooter, [System.Drawing.SolidBrush]::new($ink), 570, 920)
$g.DrawString('23:00-05:00', $fFooter, [System.Drawing.SolidBrush]::new($cyan), 1510, 920)
$g.DrawString('JEGYEK: ONETICKET.HU', $fFooter, [System.Drawing.SolidBrush]::new($ink), 570, 965)
$g.DrawString('#KeepHardstyleHardstyle', $fHash, [System.Drawing.SolidBrush]::new($cyan), 1430, 965)

# HUHS mark supplied by the project, placed in the stable lower-right rail.
$huhs = [System.Drawing.Image]::FromFile($huhsPath)
$g.DrawImage($huhs, [System.Drawing.Rectangle]::new(1745, 910, 38, 74))
$huhs.Dispose()

$g.Flush(); $g.Dispose(); $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Write-Output $outPath
