Add-Type -AssemblyName System.Drawing

$bgPath = 'C:\Users\deero\.codex\generated_images\01a05dd0-32bb-7aa3-84ab-046195582839\exec-2fe625f1-ba42-4c39-81dc-10f3cf76e545.png'
$refPath = 'C:\Users\deero\.codex\skills\huhs-hardstyle-flyers\assets\reference-flyers\15-HSREVO_220909.jpg'
$outDir = 'C:\Users\deero\hungarian_hardstyle_app\generated\flyer\hardstyle-revolution-2026-11-21'
$outPath = Join-Path $outDir 'hardstyle-revolution-facebook-clean-source.png'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$bg = [System.Drawing.Image]::FromFile($bgPath)
$ref = [System.Drawing.Image]::FromFile($refPath)
$bmp = New-Object System.Drawing.Bitmap 1920,1080
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.DrawImage($bg, 0, 0, 1920, 1080)

function Font($name, $size, $style = [System.Drawing.FontStyle]::Regular) {
  return New-Object System.Drawing.Font($name, $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
}
function Brush($hex) { return New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($hex)) }
function AlphaBrush($a, $r, $g, $b) { return New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($a, $r, $g, $b)) }
function Pen($hex, $width) { return New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($hex), $width) }

$cream = Brush '#F2EEE4'
$red = Brush '#F21E3A'
$cyan = Brush '#49E3D0'
$muted = Brush '#B6B4AE'
$black = Brush '#050608'

# Crop-safe identity rail with the supplied logo as the brand anchor.
$g.FillRectangle((Brush '#050608E6'), 1548, 54, 326, 148)
$logoRect = New-Object System.Drawing.Rectangle 1640, 205, 250, 110
$logo = New-Object System.Drawing.Bitmap 250, 110
$lg = [System.Drawing.Graphics]::FromImage($logo)
$lg.DrawImage($ref, (New-Object System.Drawing.Rectangle 0,0,250,110), $logoRect, [System.Drawing.GraphicsUnit]::Pixel)
$lg.Dispose()
$g.DrawImage($logo, (New-Object System.Drawing.Rectangle 1570, 70, 280, 123))

# Top signal: exact date and hashtag, restrained and inside the safe zone.
$g.DrawString('2026.11.21', (Font 'Agency FB' 42), $cyan, 92, 72)
$g.DrawString('#KeepHardstyleHardstyle', (Font 'Agency FB' 29), $red, 92, 128)

# Main typographic hook: reference-derived central display word, with one event-specific registration move.
$g.DrawString('H A R D S T Y L E', (Font 'Agency FB' 38), $cyan, 690, 218)
$g.DrawString('REVOLUTION', (Font 'Impact' 196), (Brush '#49E3D066'), 330, 310)
$g.DrawString('REVOLUTION', (Font 'Impact' 196), (Brush '#F21E3A88'), 304, 294)
$g.DrawString('REVOLUTION', (Font 'Impact' 196), $cream, 318, 302)
$g.DrawLine((Pen '#49E3D0' 5), 334, 534, 1588, 534)
$g.DrawString('2026.11.21  /  23:00-05:00', (Font 'Agency FB' 51), $red, 690, 555)

# Prominent, designed lineup block; no artist faces supplied, so text-only.
$g.FillRectangle((AlphaBrush 202 5 6 8), 100, 646, 1720, 170)
$g.DrawString('LINE-UP', (Font 'Agency FB' 28), $red, 130, 662)
$g.DrawString('DENOISER  |  SIDERUNNERS  |  ADAM BASS  |  IMPULZ', (Font 'Agency FB' 43), $cream, 130, 700)
$g.DrawString('CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER', (Font 'Agency FB' 43), $cream, 130, 752)

# Structured bottom signal rail, deliberately above the bottom deadzone.
$g.FillRectangle((Brush '#050608ED'), 92, 864, 1736, 142)
$g.DrawLine((Pen '#49E3D0' 3), 126, 864, 1790, 864)
$g.DrawString('STENK', (Font 'Agency FB' 40), $cream, 132, 883)
$address = '1087 BUDAPEST, KEREPESI ' + [char]0x00DA + 'T'
$g.DrawString($address, (Font 'Arial' 24), $muted, 132, 930)
$g.DrawString('JEGYEK: ONETICKET.HU', (Font 'Agency FB' 35), $red, 1348, 892)
$g.DrawString('23:00-05:00', (Font 'Agency FB' 34), $cyan, 1348, 940)

# Subtle edge registration marks echo the reference grammar without copying it.
$g.DrawLine((Pen '#F21E3A66' 2), 58, 222, 58, 790)
$g.DrawLine((Pen '#49E3D066' 2), 1860, 222, 1860, 790)

$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$logo.Dispose(); $ref.Dispose(); $bg.Dispose(); $g.Dispose(); $bmp.Dispose()
Write-Output $outPath
