# A Sideloadly ablakban a fajlvalaszto "also" vezerloi: a fajlnev-mezo es a gombok.
# A lista-oszlopok (Nev / Modositas datuma / Tipus / Meret) szandekosan kimaradnak.
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$p = Get-Process sideloadly -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { "NINCS Sideloadly ablak"; exit 2 }
$root = [System.Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle)

$skip = @('Nev', 'Név', 'Modositas datuma', 'Módosítás dátuma', 'Tipus', 'Típus', 'Meret', 'Méret')
$all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants,
  [System.Windows.Automation.Condition]::TrueCondition)
"elemek: $($all.Count)"
foreach ($e in $all) {
  $c = $e.Current
  $type = $c.ControlType.ProgrammaticName.Replace('ControlType.', '')
  if ($type -notin @('Edit', 'Button', 'ComboBox')) { continue }
  if ($skip -contains $c.Name) { continue }
  if ($c.AutomationId -like 'System.*') { continue }
  $rect = '?'
  try {
    $r = $c.BoundingRectangle
    $rect = '{0},{1} {2}x{3}' -f [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height
  } catch { }
  "[{0}] name='{1}' auto='{2}' enabled={3} rect={4}" -f $type, $c.Name, $c.AutomationId, $c.IsEnabled, $rect
}
