Add-Type -AssemblyName System.Drawing

$ref = 'C:\Users\deero\.codex\skills\huhs-hardstyle-flyers\assets\reference-flyers\01-PRE.jpg'
$logoSource = [System.Drawing.Bitmap]::new($ref)

function New-Font($name, $size, $style = [System.Drawing.FontStyle]::Regular) {
  [System.Drawing.Font]::new($name, $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
}

function Draw-Text($g, $text, $font, $color, $x, $y) {
  $brush = [System.Drawing.SolidBrush]::new($color)
  $g.DrawString($text, $font, $brush, $x, $y)
  $brush.Dispose(); $font.Dispose()
}

function Fit-Font($g, $text, $family, $maxWidth, $size, $style = [System.Drawing.FontStyle]::Regular) {
  while ($size -gt 14) {
    $font = New-Font $family $size $style
    if ($g.MeasureString($text, $font).Width -le $maxWidth) { return $font }
    $font.Dispose(); $size -= 2
  }
  New-Font $family 14 $style
}

function Get-Logo {
  $logo = [System.Drawing.Bitmap]::new(540, 230, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $lg = [System.Drawing.Graphics]::FromImage($logo)
  $lg.DrawImage($logoSource, [System.Drawing.Rectangle]::new(0,0,540,230), [System.Drawing.Rectangle]::new(270,405,620,260), [System.Drawing.GraphicsUnit]::Pixel)
  $lg.Dispose()
  for ($y=0; $y -lt $logo.Height; $y++) {
    for ($x=0; $x -lt $logo.Width; $x++) {
      $p = $logo.GetPixel($x,$y)
      $max = [Math]::Max($p.R,[Math]::Max($p.G,$p.B)); $min = [Math]::Min($p.R,[Math]::Min($p.G,$p.B))
      if ($max -lt 155 -or ($max-$min) -gt 80) { $logo.SetPixel($x,$y,[System.Drawing.Color]::Transparent) }
    }
  }
  $logo
}

function Make-Flyer($background, $output, $mode) {
  $bmp = [System.Drawing.Bitmap]::new($background)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $red = [System.Drawing.Color]::FromArgb(245,20,34)
  $white = [System.Drawing.Color]::FromArgb(247,244,238)
  $cyan = [System.Drawing.Color]::FromArgb(59,224,240)
  $muted = [System.Drawing.Color]::FromArgb(210,211,218,219)
  $address = '1087 Budapest, Kerepesi ' + [char]0x00FA + 't'
  $darkBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(178,2,6,12))
  $g.FillRectangle($darkBrush, 145, 95, 1020, 810); $darkBrush.Dispose()
  $accentBrush = [System.Drawing.SolidBrush]::new($red)
  $g.FillRectangle($accentBrush, 145, 95, 10, 810); $accentBrush.Dispose()
  $logo = Get-Logo
  $g.DrawImage($logo, 185, 112, 350, 149); $logo.Dispose()

  if ($mode -eq 'industrial') {
    Draw-Text $g '#KeepHardstyleHardstyle' (New-Font 'Arial Narrow' 28 ([System.Drawing.FontStyle]::Bold)) $cyan 185 272
    Draw-Text $g 'HARDSTYLE' (New-Font 'Impact' 112) $white 180 312
    Draw-Text $g 'REVOLUTION' (New-Font 'Impact' 94) $red 180 425
    Draw-Text $g '2026.11.21' (New-Font 'Impact' 52) $white 185 540
    Draw-Text $g '23:00-05:00' (New-Font 'Arial Narrow' 36 ([System.Drawing.FontStyle]::Bold)) $cyan 480 555
    Draw-Text $g 'STENK' (New-Font 'Arial Narrow' 35 ([System.Drawing.FontStyle]::Bold)) $white 185 610
    Draw-Text $g $address (New-Font 'Segoe UI' 25 ([System.Drawing.FontStyle]::Bold)) $white 185 652
    Draw-Text $g 'JEGYEK: ONETICKET.HU' (New-Font 'Arial Narrow' 21 ([System.Drawing.FontStyle]::Bold)) $muted 185 695
    $panel=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(225,5,9,15));$g.FillRectangle($panel,175,735,935,145);$panel.Dispose()
    Draw-Text $g 'LINEUP' (New-Font 'Arial Narrow' 25 ([System.Drawing.FontStyle]::Bold)) $red 200 747
    Draw-Text $g 'DENOISER  |  SIDERRUNNERS  |  ADAM BASS  |  IMPULZ' (Fit-Font $g 'DENOISER  |  SIDERRUNNERS  |  ADAM BASS  |  IMPULZ' 'Arial Narrow' 850 34 ([System.Drawing.FontStyle]::Bold)) $white 200 780
    Draw-Text $g 'CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER' (Fit-Font $g 'CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER' 'Arial Narrow' 850 34 ([System.Drawing.FontStyle]::Bold)) $white 200 828
  } elseif ($mode -eq 'neon') {
    Draw-Text $g '#KeepHardstyleHardstyle' (New-Font 'Arial Narrow' 27 ([System.Drawing.FontStyle]::Bold)) $cyan 185 275
    Draw-Text $g 'HARDSTYLE' (New-Font 'Impact' 104) $white 180 315
    Draw-Text $g 'REVOLUTION' (New-Font 'Impact' 88) $cyan 180 422
    Draw-Text $g '2026.11.21  /  23:00-05:00' (New-Font 'Arial Narrow' 31 ([System.Drawing.FontStyle]::Bold)) $white 185 540
    Draw-Text $g ('STENK  |  ' + $address) (New-Font 'Segoe UI' 24 ([System.Drawing.FontStyle]::Bold)) $white 185 590
    Draw-Text $g 'JEGYEK: ONETICKET.HU' (New-Font 'Arial Narrow' 21 ([System.Drawing.FontStyle]::Bold)) $muted 185 632
    $panel=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(215,10,10,30));$g.FillRectangle($panel,175,680,980,180);$panel.Dispose()
    Draw-Text $g 'LINEUP' (New-Font 'Arial Narrow' 26 ([System.Drawing.FontStyle]::Bold)) $red 205 694
    Draw-Text $g 'DENOISER  |  SIDERRUNNERS  |  ADAM BASS' (Fit-Font $g 'DENOISER  |  SIDERRUNNERS  |  ADAM BASS' 'Arial Narrow' 900 35 ([System.Drawing.FontStyle]::Bold)) $white 205 730
    Draw-Text $g 'IMPULZ  |  CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER' (Fit-Font $g 'IMPULZ  |  CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER' 'Arial Narrow' 900 31 ([System.Drawing.FontStyle]::Bold)) $white 205 782
    Draw-Text $g 'HARDSTYLE REVOLUTION' (New-Font 'Arial Narrow' 19 ([System.Drawing.FontStyle]::Bold)) $cyan 205 832
  } else {
    Draw-Text $g '#KeepHardstyleHardstyle' (New-Font 'Arial Narrow' 27 ([System.Drawing.FontStyle]::Bold)) $red 185 275
    Draw-Text $g 'HARDSTYLE' (New-Font 'Impact' 104) $white 180 315
    Draw-Text $g 'REVOLUTION' (New-Font 'Impact' 88) $red 180 422
    Draw-Text $g '2026.11.21' (New-Font 'Impact' 50) $white 185 535
    Draw-Text $g '23:00-05:00' (New-Font 'Arial Narrow' 35 ([System.Drawing.FontStyle]::Bold)) $red 475 550
    Draw-Text $g 'STENK' (New-Font 'Arial Narrow' 35 ([System.Drawing.FontStyle]::Bold)) $white 185 600
    Draw-Text $g $address (New-Font 'Segoe UI' 24 ([System.Drawing.FontStyle]::Bold)) $white 185 642
    Draw-Text $g 'JEGYEK: ONETICKET.HU' (New-Font 'Arial Narrow' 21 ([System.Drawing.FontStyle]::Bold)) $muted 185 682
    $panel=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(230,4,5,7));$g.FillRectangle($panel,175,720,960,165);$panel.Dispose()
    Draw-Text $g 'LINEUP' (New-Font 'Arial Narrow' 26 ([System.Drawing.FontStyle]::Bold)) $red 205 734
    Draw-Text $g 'DENOISER  |  SIDERRUNNERS  |  ADAM BASS  |  IMPULZ' (Fit-Font $g 'DENOISER  |  SIDERRUNNERS  |  ADAM BASS  |  IMPULZ' 'Arial Narrow' 870 33 ([System.Drawing.FontStyle]::Bold)) $white 205 768
    Draw-Text $g 'CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER' (Fit-Font $g 'CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER' 'Arial Narrow' 870 33 ([System.Drawing.FontStyle]::Bold)) $red 205 815
  }
  $g.Dispose(); $bmp.Save($output,[System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

$base='C:\Users\deero\.codex\generated_images\01a05dd0-32bb-7aa3-84ab-046195582839'
Make-Flyer "$base\exec-dd8aef7e-c998-44be-ac79-87e1c3f8096d.png" "$base\hardstyle-revolution-2026-11-21-industrial-clean.png" 'industrial'
Make-Flyer "$base\exec-178260e3-1f55-4ba8-9d63-47ec085662c0.png" "$base\hardstyle-revolution-2026-11-21-neon-clean.png" 'neon'
Make-Flyer "$base\exec-ed6942a2-2ad6-498f-9e30-bd93bb28cbc1.png" "$base\hardstyle-revolution-2026-11-21-horror-clean.png" 'horror'
$logoSource.Dispose()
