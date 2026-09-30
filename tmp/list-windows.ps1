# Az osszes top-level ablak (nev, osztaly, pid, méret) — csak olvasas.
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$desktop = [System.Windows.Automation.AutomationElement]::RootElement
$windows = $desktop.FindAll([System.Windows.Automation.TreeScope]::Children,
  [System.Windows.Automation.Condition]::TrueCondition)
"top-level ablakok: $($windows.Count)"
foreach ($w in $windows) {
  $c = $w.Current
  $r = $c.BoundingRectangle
  "{0,-45} class='{1}' pid={2} rect={3},{4} {5}x{6}" -f `
    ("'" + $c.Name + "'"), $c.ClassName, $c.ProcessId, [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height
}
