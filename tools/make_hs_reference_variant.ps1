# LEGACY TEST SCRIPT ONLY. Do not use for delivery: it intentionally contains
# the old repeated left-title layout that the typography anti-template gate forbids.
# Create a fresh composition with a new reference-derived type system instead.
Add-Type -AssemblyName System.Drawing

$base = 'C:\Users\deero\.codex\generated_images\01a05dd0-32bb-7aa3-84ab-046195582839'
$background = "$base\exec-7179096d-f428-4c9f-9fb6-a0276c4c3f83.png"
$ref = 'C:\Users\deero\.codex\skills\huhs-hardstyle-flyers\assets\reference-flyers\01-PRE.jpg'
$out = "$base\hardstyle-revolution-2026-11-21-reference-club.png"

function Font($name,$size,$style=[System.Drawing.FontStyle]::Regular) { [System.Drawing.Font]::new($name,$size,$style,[System.Drawing.GraphicsUnit]::Pixel) }
function Text($g,$s,$font,$color,$x,$y) { $b=[System.Drawing.SolidBrush]::new($color); $g.DrawString($s,$font,$b,$x,$y); $b.Dispose(); $font.Dispose() }
function Fit($g,$s,$family,$max,$size,$style=[System.Drawing.FontStyle]::Regular) { while($size -gt 15) { $f=Font $family $size $style; if($g.MeasureString($s,$f).Width -le $max){return $f};$f.Dispose();$size-=2 }; Font $family 15 $style }

$src=[System.Drawing.Bitmap]::new($background)
$bmp=[System.Drawing.Bitmap]::new($src.Width,$src.Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.DrawImage($src,0,0,$bmp.Width,$bmp.Height)
$g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$white=[System.Drawing.Color]::FromArgb(248,245,237); $red=[System.Drawing.Color]::FromArgb(246,24,39); $cyan=[System.Drawing.Color]::FromArgb(66,226,238); $pale=[System.Drawing.Color]::FromArgb(215,216,221)

# Real HUHS logo extracted from the supplied flyer reference, not generated.
$logo=[System.Drawing.Bitmap]::new(540,230,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$lg=[System.Drawing.Graphics]::FromImage($logo);$lg.DrawImage([System.Drawing.Bitmap]::new($ref),[System.Drawing.Rectangle]::new(0,0,540,230),[System.Drawing.Rectangle]::new(270,405,620,260),[System.Drawing.GraphicsUnit]::Pixel);$lg.Dispose()
for($y=0;$y -lt $logo.Height;$y++){for($x=0;$x -lt $logo.Width;$x++){ $p=$logo.GetPixel($x,$y);$mx=[Math]::Max($p.R,[Math]::Max($p.G,$p.B));$mn=[Math]::Min($p.R,[Math]::Min($p.G,$p.B));if($mx -lt 155 -or ($mx-$mn) -gt 80){$logo.SetPixel($x,$y,[System.Drawing.Color]::Transparent)}}}
$g.DrawImage($logo,102,72,300,128);$logo.Dispose()

# Reference-led hierarchy: small date, enormous two-line title, prominent artist block, restrained facts.
Text $g '2026.11.21' (Font 'Arial Narrow' 38 ([System.Drawing.FontStyle]::Bold)) $red 105 228
Text $g '#KeepHardstyleHardstyle' (Font 'Arial Narrow' 22 ([System.Drawing.FontStyle]::Bold)) $white 1290 92
Text $g 'HARDSTYLE' (Font 'Impact' 91) $white 100 292
Text $g 'REVOLUTION' (Font 'Impact' 78) $red 100 382
$line=[System.Drawing.SolidBrush]::new($red);$g.FillRectangle($line,105,488,650,7);$line.Dispose()

Text $g 'DENOISER  |  SIDERRUNNERS' (Fit $g 'DENOISER  |  SIDERRUNNERS' 'Arial Narrow' 660 34 ([System.Drawing.FontStyle]::Bold)) $white 105 520
Text $g 'ADAM BASS  |  IMPULZ' (Fit $g 'ADAM BASS  |  IMPULZ' 'Arial Narrow' 660 34 ([System.Drawing.FontStyle]::Bold)) $white 105 562
Text $g 'CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER' (Fit $g 'CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER' 'Arial Narrow' 660 29 ([System.Drawing.FontStyle]::Bold)) $red 105 604

Text $g '23:00-05:00' (Font 'Arial Narrow' 30 ([System.Drawing.FontStyle]::Bold)) $red 105 720
Text $g 'STENK' (Font 'Arial Narrow' 30 ([System.Drawing.FontStyle]::Bold)) $white 300 720
$address = '1087 Budapest, Kerepesi ' + [char]0x00FA + 't'
Text $g $address (Font 'Arial Narrow' 21 ([System.Drawing.FontStyle]::Bold)) $pale 105 762
Text $g 'JEGYEK: ONETICKET.HU' (Font 'Arial Narrow' 20 ([System.Drawing.FontStyle]::Bold)) $white 105 800

$g.Dispose();$bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Png);$bmp.Dispose();$src.Dispose()
Write-Output $out
