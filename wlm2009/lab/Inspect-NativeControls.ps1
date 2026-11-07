# Somente geometria/AutomationId/ControlType da interface NATIVA do WLM 2009.
# Nunca coleta nome de contato, texto de janela, email, senhas ou imagens.
[CmdletBinding()]
param([string]$OutputPath='E:\StormMSN-Research\analysis\integrity\WLM2009-native-controls.json')
$ErrorActionPreference='Stop'
$lab='E:\StormMSN-Research\analysis\integrity'
$windowsFile=Join-Path $lab 'WLM2009-native-windows-for-uia.json'
& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $lab 'Inspect-NativeWindows.ps1') -OutputPath $windowsFile | Out-Null
$j=Get-Content -LiteralPath $windowsFile -Encoding UTF8 -Raw | ConvertFrom-Json
$target=@($j.windows|Where-Object {$_.Class -eq 'MSBLWindowClass' -and $_.Visible -and $_.Width -ge 150 -and $_.Height -ge 150}|Select-Object -First 1)
if($target.Count -eq 0){Write-Output 'NO_VISIBLE_NATIVE_WLM_WINDOW';exit 2}
$win=$target[0]
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$ptr=[IntPtr]([Convert]::ToInt64($win.Handle.Substring(2),16))
$root=[System.Windows.Automation.AutomationElement]::FromHandle($ptr)
if($null -eq $root){throw 'AutomationElement.FromHandle returned null'}
$results=New-Object System.Collections.Generic.List[object]
$nodes=$root.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
for($i=0;$i -lt [Math]::Min($nodes.Count,180);$i++){
  $node=$nodes.Item($i)
  try {
    $c=$node.Current
    $rect=$c.BoundingRectangle
    $results.Add([pscustomobject][ordered]@{
      id=$i
      controlType=[string]$c.ControlType.ProgrammaticName
      automationId=[string]$c.AutomationId
      frameworkId=[string]$c.FrameworkId
      x=[math]::Round($rect.Left,1)
      y=[math]::Round($rect.Top,1)
      width=[math]::Round($rect.Width,1)
      height=[math]::Round($rect.Height,1)
    })
  }catch{ }
}
$report=[pscustomobject][ordered]@{
  session=[Diagnostics.Process]::GetCurrentProcess().SessionId
  windowClass=$win.Class
  windowWidth=$win.Width
  windowHeight=$win.Height
  windowDpi=$win.Dpi
  totalAutomationNodes=$nodes.Count
  includedNodes=$results.Count
  controls=@($results.ToArray())
  note='Metadata only; no window labels, input values, contact names or pixels'
}
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath),($report|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
Write-Output ('NATIVE_WLM '+$win.Width+'x'+$win.Height+' DPI='+$win.Dpi)
Write-Output ('UIA_NODES '+$nodes.Count+' RECORDED '+$results.Count)
foreach($item in $results){
 if($item.width -gt 25 -and $item.height -gt 10){Write-Output ('CTRL '+$item.controlType+' '+$item.automationId+' '+$item.width+'x'+$item.height)}
}
