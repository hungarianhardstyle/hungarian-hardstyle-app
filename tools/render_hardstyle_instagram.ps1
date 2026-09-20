Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Drawing.Common -ErrorAction SilentlyContinue

$outDir = Join-Path (Get-Location) 'generated/instagram'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$out = Join-Path $outDir 'magyar-hardstyle-nemzetkozi-instagram.png'

$w = 1350; $h = 1080
$bmp = New-Object System.Drawing.Bitmap($w,$h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$bg = [System.Drawing.Color]::FromArgb(8,9,12)
$g.Clear($bg)
$rand = New-Object System.Random(241121)

function Brush($hex) { New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($hex)) }
function Pen($hex,$width) { New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($hex),$width) }

# Procedural, non-photographic texture: screenprint grain + offset registration geometry.
for ($i=0; $i -lt 2600; $i++) {
  $x = $rand.Next(0,$w); $y = $rand.Next(0,$h); $a = $rand.Next(12,45)
  $c = if ($i % 3 -eq 0) {[System.Drawing.Color]::FromArgb($a,215,25,48)} elseif ($i % 3 -eq 1) {[System.Drawing.Color]::FromArgb($a,26,214,195)} else {[System.Drawing.Color]::FromArgb($a,230,230,214)}
  $b = New-Object System.Drawing.SolidBrush($c)
  $s = $rand.Next(1,4); $g.FillRectangle($b,$x,$y,$s,$s); $b.Dispose()
}

$red = Brush '#D8193F'; $cyan = Brush '#2BE4CF'; $cream = Brush '#F2EFE4'; $muted = Brush '#A8AAA6'; $black = Brush '#08090C'
$g.FillRectangle($red,0,0,16,$h)
$g.FillRectangle($cyan,16,0,5,$h)
$g.FillRectangle($red,0,0,450,18)
$g.FillRectangle($cyan,900,1062,450,5)

# Angular, restrained hardstyle energy fields.
$pRed = Pen '#D8193F' 2; $pCyan = Pen '#2BE4CF' 1
$g.DrawLine($pRed,100,40,520,390); $g.DrawLine($pRed,0,300,300,0)
$g.DrawLine($pCyan,930,0,1350,420); $g.DrawLine($pCyan,880,1080,1350,610)
$g.DrawLine($pRed,1040,200,1350,40); $g.DrawLine($pCyan,0,850,300,1080)
for ($i=0; $i -lt 13; $i++) {
  $x = 58 + ($i*78); $g.DrawLine((Pen '#D8193F' 1),$x,1020,$x+220,800)
}
# Halftone blocks behind the copy, intentionally abstract and text-free.
for ($row=0; $row -lt 9; $row++) { for ($col=0; $col -lt 16; $col++) {
  if (($row+$col) % 2 -eq 0) {
    $a = 12 + (($row*7+$col*3) % 17)
    $c = [System.Drawing.Color]::FromArgb($a,40,228,207); $b = New-Object System.Drawing.SolidBrush($c)
    $g.FillRectangle($b,570+$col*28,120+$row*28,9,9); $b.Dispose()
  }
}}

function DrawFit($text,$fontName,$size,$x,$y,$maxWidth,$color) {
  $font = New-Object System.Drawing.Font($fontName,$size,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
  $g.DrawString($text,$font,(Brush $color),$x,$y)
  $font.Dispose()
}

function Wrap($text,$fontName,$size,$maxWidth) {
  $font = New-Object System.Drawing.Font($fontName,$size,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
  $words = $text.Split(' '); $lines = New-Object System.Collections.Generic.List[string]; $line=''
  foreach ($word in $words) {
    $test = if ($line) { "$line $word" } else { $word }
    if ($g.MeasureString($test,$font).Width -gt $maxWidth -and $line) { $lines.Add($line); $line=$word } else { $line=$test }
  }
  if ($line) { $lines.Add($line) }; $font.Dispose(); return $lines
}

$titleFont = New-Object System.Drawing.Font('Agency FB',56,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$bodyFont = New-Object System.Drawing.Font('Bahnschrift SemiCondensed',29,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$smallFont = New-Object System.Drawing.Font('Bahnschrift SemiCondensed',27,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)

# Text block stays inside a 72px safe frame on all sides.
$x=100; $y=130
$g.DrawString('Magyar hardstyle a',$titleFont,$cream,$x,$y)
$g.DrawString('nemzetközi színtéren',$titleFont,$cream,$x,$y+58)
$emoji = [char]::ConvertFromUtf32(0x1F30D)+[char]::ConvertFromUtf32(0x1F50A)
$emojiFont = New-Object System.Drawing.Font('Segoe UI Emoji',34,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString($emoji,$emojiFont,$cream,1110,$y+64)

$linePen = Pen '#D8193F' 5; $g.DrawLine($linePen,100,270,1250,270)
$linePen.Dispose()

$body = 'Úgy látom, hogy a hazai hardstyle előadók közül főleg a régebb óta aktív nevek jutottak el külföldi fellépésekre.'
$lines = Wrap $body 'Bahnschrift SemiCondensed' 29 1130
$yy=310
foreach ($ln in $lines) { $g.DrawString($ln,$bodyFont,$muted,$x,$yy); $yy += 38 }

$yy += 30
$third = 'Szerintetek kik azok az újabb generációs DJ-k és producerek, akik megérdemelnének egy lehetőséget nemzetközi line-upokban is? Jöhetnek nevek, trackek és személyes ajánlások!'
$lines2 = Wrap $third 'Bahnschrift SemiCondensed' 27 1130
foreach ($ln in $lines2) { $g.DrawString($ln,$smallFont,$cream,$x,$yy); $yy += 36 }
$fire = [char]::ConvertFromUtf32(0x1F525)
$fireFont = New-Object System.Drawing.Font('Segoe UI Emoji',28,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString($fire,$fireFont,$cream,936,[Math]::Min($yy-36,1000))

# Small visual anchor, no extra copy.
$g.FillRectangle($red,78,965,90,8); $g.FillRectangle($cyan,178,965,32,8); $g.FillRectangle($cream,220,965,12,8)

$bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Png)
$fireFont.Dispose(); $emojiFont.Dispose(); $smallFont.Dispose(); $bodyFont.Dispose(); $titleFont.Dispose()
$red.Dispose(); $cyan.Dispose(); $cream.Dispose(); $muted.Dispose(); $black.Dispose(); $pRed.Dispose(); $pCyan.Dispose(); $g.Dispose(); $bmp.Dispose()
Write-Output $out
