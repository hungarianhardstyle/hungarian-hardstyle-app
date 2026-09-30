# Az osszes ablak listazasa, ami fajlvalaszto lehet (nev szerint), es a benne levo
# Edit/Button vezerlok kiirasa — csak olvasas, semmit nem kattint.
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$desktop = [System.Windows.Automation.AutomationElement]::RootElement
$windows = $desktop.FindAll([System.Windows.Automation.TreeScope]::Children,
  [System.Windows.Automation.Condition]::TrueCondition)

"osszes top-level ablak: $($windows.Count)"
foreach ($w in $windows) {
  $c = $w.Current
  $title = $c.Name
  if ($title -match 'Megnyit|Open|Fajl|Fájl|File|Sideload') {
    "=== '$title' class='$($c.ClassName)' pid=$($c.ProcessId) ==="
    $all = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants,
      [System.Windows.Automation.Condition]::TrueCondition)
    foreach ($e in $all) {
      $ec = $e.Current
      $type = $ec.ControlType.ProgrammaticName.Replace('ControlType.', '')
      if ($type -in @('Edit', 'Button') -and ($ec.Name -or $ec.AutomationId)) {
        $rect = ''
        try {
          $r = $ec.BoundingRectangle
          $rect = '{0},{1} {2}x{3}' -f [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height
        } catch { $rect = '?' }
        "  [$type] name='$($ec.Name)' auto='$($ec.AutomationId)' rect=$rect"
      }
    }
  }
}
