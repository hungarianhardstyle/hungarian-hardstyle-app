# A Sideloadly ablak rovid allapota: elemszam + a szoveges elemek (IPA nev, statusz)
# es a Start gomb allapota. Csak olvasas.
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$p = Get-Process sideloadly -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { "NINCS Sideloadly ablak"; exit 2 }
$root = [System.Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle)

$all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants,
  [System.Windows.Automation.Condition]::TrueCondition)
"elemek: $($all.Count)"

foreach ($e in $all) {
  $c = $e.Current
  $type = $c.ControlType.ProgrammaticName.Replace('ControlType.', '')
  if ($type -eq 'Text') { "[Text] '$($c.Name)'" }
  if ($type -eq 'Button' -and $c.Name -eq 'Start') { "[Start] enabled=$($c.IsEnabled)" }
}
