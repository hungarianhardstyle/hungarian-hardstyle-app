# A Sideloadly IPA-választó megnyitása UIAutomation-nel (a nagy IPA-terület gombjára
# kattintva), majd a megjelenő ablakok kilistázása — még NEM választ fájlt.
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$p = Get-Process sideloadly -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { "NINCS Sideloadly ablak"; exit 2 }

$root = [System.Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle)

# A nagy IPA-gomb: az egyetlen 93x109-es vezérlő.
$cond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button)
$buttons = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
$target = $null
foreach ($b in $buttons) {
  $r = $b.Current.BoundingRectangle
  if ([int]$r.Width -eq 93 -and [int]$r.Height -eq 109) { $target = $b; break }
}
if (-not $target) { "NINCS 93x109-es IPA-gomb"; exit 3 }

"IPA-gomb megnyomása (Invoke)…"
$inv = $target.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
$inv.Invoke()
Start-Sleep -Seconds 3

# Minden ablak, ami ehhez a folyamathoz tartozik (a fájlválasztó is).
$desktop = [System.Windows.Automation.AutomationElement]::RootElement
$procCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ProcessIdProperty, $p.Id)
$windows = $desktop.FindAll([System.Windows.Automation.TreeScope]::Children, $procCond)
"ablakok ehhez a folyamathoz: $($windows.Count)"
foreach ($w in $windows) {
  "=== '$($w.Current.Name)' class='$($w.Current.ClassName)' ==="
  $all = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants,
    [System.Windows.Automation.Condition]::TrueCondition)
  foreach ($e in $all) {
    $c = $e.Current
    $type = $c.ControlType.ProgrammaticName.Replace('ControlType.', '')
    if ($type -in @('Edit', 'Button', 'ComboBox', 'Text', 'Tree', 'ListItem') -and ($c.Name -or $c.AutomationId)) {
      "  [$type] name='$($c.Name)' auto='$($c.AutomationId)'"
    }
  }
}
