# A megnyilt fajlvalaszto kitoltese es elfogadasa (UIAutomation).
#
# MIERT: a Sideloadly a parancssori argumentumot ezen a gepen elrontotta (`-r`
# neven kereste az IPA-t), ezert a fajlt a FELULETEN keresztul adjuk meg.
# FONTOS: ez a szkript szandekosan CSAK ASCII karaktereket hasznal, mert a
# Windows PowerShell 5.1 a BOM nelkuli UTF-8 fajlt a rendszer kodlapjakent
# olvassa, es a magyar ekezetek egy resze idezojelkent viselkedik (parse hiba).
param([string]$Ipa = "$env:USERPROFILE\hh383.ipa")

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$p = Get-Process sideloadly -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { "NINCS Sideloadly ablak"; exit 2 }

$desktop = [System.Windows.Automation.AutomationElement]::RootElement
$procCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ProcessIdProperty, $p.Id)
$windows = $desktop.FindAll([System.Windows.Automation.TreeScope]::Children, $procCond)

$nameEdit = $null
$openButton = $null
foreach ($w in $windows) {
  $all = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants,
    [System.Windows.Automation.Condition]::TrueCondition)
  foreach ($e in $all) {
    $c = $e.Current
    $type = $c.ControlType.ProgrammaticName.Replace('ControlType.', '')
    if ($type -eq 'Edit' -and $c.AutomationId -eq '1148') { $nameEdit = $e }
    if ($type -eq 'Button' -and $c.AutomationId -eq '1') { $openButton = $e }
  }
}

"fajlnev-mezo: $($null -ne $nameEdit)  megnyitas-gomb: $($null -ne $openButton)"
if (-not $nameEdit) { "NINCS fajlnev-mezo (1148)"; exit 3 }

$vp = $nameEdit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
$vp.SetValue($Ipa)
"beirva: $Ipa"
Start-Sleep -Milliseconds 600

if ($openButton) {
  $openButton.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
  "MEGNYITAS MEGNYOMVA"
} else {
  "NINCS megnyitas-gomb (1)"
}
Start-Sleep -Seconds 5
