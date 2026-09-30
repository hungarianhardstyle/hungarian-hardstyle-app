# A Sideloadly ablak TELJES UI-fája (minden elem, értékkel együtt) — csak olvasás.
#
# MIÉRT: a képernyőkép ebben a munkamenetben üres (a desktop nem renderel), ezért a
# felület állapotát (melyik IPA van betöltve, mi a státusz) UIAutomationnel kell
# kiolvasni. Ez a szkript nem kattint semmire.
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$p = Get-Process sideloadly -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { "NINCS Sideloadly ablak"; exit 2 }

$root = [System.Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle)
"Ablak: '$($root.Current.Name)'"
$all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants,
  [System.Windows.Automation.Condition]::TrueCondition)
"Elemek: $($all.Count)"
""

foreach ($e in $all) {
  $c = $e.Current
  $type = $c.ControlType.ProgrammaticName.Replace('ControlType.', '')
  $value = ''
  try {
    $vp = $e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
    $value = $vp.Current.Value
  } catch { }
  $rect = '{0},{1} {2}x{3}' -f [int]$c.BoundingRectangle.X, [int]$c.BoundingRectangle.Y,
    [int]$c.BoundingRectangle.Width, [int]$c.BoundingRectangle.Height
  "[{0}] name='{1}' auto='{2}' value='{3}' enabled={4} rect={5}" -f `
    $type, $c.Name, $c.AutomationId, $value, $c.IsEnabled, $rect
}
