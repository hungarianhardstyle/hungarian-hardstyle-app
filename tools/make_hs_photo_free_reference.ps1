Add-Type -AssemblyName System.Drawing

$base='C:\Users\deero\.codex\generated_images\01a05dd0-32bb-7aa3-84ab-046195582839'
$background="$base\exec-db2ea3ab-b464-4e84-b7c0-6eb46f651705.png"
$ref='C:\Users\deero\.codex\skills\huhs-hardstyle-flyers\assets\reference-flyers\01-PRE.jpg'
$out="$base\hardstyle-revolution-2026-11-21-photo-free-reference.png"

function F($name,$size,$style=[System.Drawing.FontStyle]::Regular){[System.Drawing.Font]::new($name,$size,$style,[System.Drawing.GraphicsUnit]::Pixel)}
function T($g,$s,$font,$color,$x,$y){$b=[System.Drawing.SolidBrush]::new($color);$g.DrawString($s,$font,$b,$x,$y);$b.Dispose();$font.Dispose()}
function Fit($g,$s,$family,$max,$size,$style=[System.Drawing.FontStyle]::Regular){while($size -gt 14){$f=F $family $size $style;if($g.MeasureString($s,$f).Width -le $max){return $f};$f.Dispose();$size-=2};F $family 14 $style}
function Center($g,$s,$font,$color,$cx,$y){$b=[System.Drawing.SolidBrush]::new($color);$m=$g.MeasureString($s,$font);$g.DrawString($s,$font,$b,$cx-($m.Width/2),$y);$b.Dispose();$font.Dispose()}

$src=[System.Drawing.Bitmap]::new($background);$bmp=[System.Drawing.Bitmap]::new($src.Width,$src.Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.DrawImage($src,0,0,$bmp.Width,$bmp.Height);$g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::HighQuality;$g.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$cream=[System.Drawing.Color]::FromArgb(246,242,229);$red=[System.Drawing.Color]::FromArgb(239,30,43);$teal=[System.Drawing.Color]::FromArgb(70,223,197);$muted=[System.Drawing.Color]::FromArgb(213,214,211)

# Authentic supplied Hardstyle Revolution logo, extracted from a user reference.
$rs=[System.Drawing.Bitmap]::new($ref);$logo=[System.Drawing.Bitmap]::new(540,230,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);$lg=[System.Drawing.Graphics]::FromImage($logo);$lg.DrawImage($rs,[System.Drawing.Rectangle]::new(0,0,540,230),[System.Drawing.Rectangle]::new(270,405,620,260),[System.Drawing.GraphicsUnit]::Pixel);$lg.Dispose();$rs.Dispose()
for($y=0;$y -lt $logo.Height;$y++){for($x=0;$x -lt $logo.Width;$x++){$p=$logo.GetPixel($x,$y);$mx=[Math]::Max($p.R,[Math]::Max($p.G,$p.B));$mn=[Math]::Min($p.R,[Math]::Min($p.G,$p.B));if($mx -lt 155 -or ($mx-$mn) -gt 80){$logo.SetPixel($x,$y,[System.Drawing.Color]::Transparent)}}}
$g.DrawImage($logo,1325,82,250,107);$logo.Dispose()

# Photo-free reference typography: small spaced kicker, offset display word, dense single artist rail.
T $g '#KeepHardstyleHardstyle' (F 'Arial Narrow' 21 ([System.Drawing.FontStyle]::Bold)) $cream 100 92
T $g '2026.11.21' (F 'Arial Narrow' 35 ([System.Drawing.FontStyle]::Bold)) $red 100 170

$kicker='H A R D S T Y L E';Center $g $kicker (F 'Arial Narrow' 29 ([System.Drawing.FontStyle]::Bold)) $teal 836 238
$main='REVOLUTION';$mf=F 'Impact' 158;$mw=$g.MeasureString($main,$mf).Width;$mx=(836-($mw/2))
T $g $main (F 'Impact' 158) $teal ($mx-7) 286
T $g $main (F 'Impact' 158) $cream $mx 278
T $g $main (F 'Impact' 158) $red ($mx+7) 270

$artists='DENOISER  |  SIDERRUNNERS  |  ADAM BASS  |  IMPULZ  |  CAPITAL NOISE  |  DR FOLLI  |  NOIZEMAKER'
$af=Fit $g $artists 'Arial Narrow' 1450 30 ([System.Drawing.FontStyle]::Bold);$aw=$g.MeasureString($artists,$af).Width;T $g $artists $af $cream ((1672-$aw)/2) 540
$line=[System.Drawing.SolidBrush]::new($teal);$g.FillRectangle($line,240,600,1192,3);$line.Dispose()

$facts='23:00-05:00  |  STENK  |  1087 Budapest, Kerepesi ' + [char]0x00FA + 't  |  JEGYEK: ONETICKET.HU'
$ff=Fit $g $facts 'Arial Narrow' 1330 25 ([System.Drawing.FontStyle]::Bold);$fw=$g.MeasureString($facts,$ff).Width;T $g $facts $ff $cream ((1672-$fw)/2) 635

$g.Dispose();$bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Png);$bmp.Dispose();$src.Dispose();Write-Output $out
