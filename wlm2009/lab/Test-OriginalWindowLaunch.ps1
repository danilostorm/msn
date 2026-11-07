# Diagnostico controlado de abertura do cliente ORIGINAL, na sessao grafica.
# Nao modifica binarios, INI, DLL, registro, contatos ou credenciais.
[CmdletBinding()]
param(
  [string]$Report = 'E:\StormMSN-Research\analysis\integrity\WLM2009-controlled-launch-report.json'
)
$ErrorActionPreference = 'Stop'
$exe = 'C:\Program Files (x86)\Windows Live\Messenger\msnmsgr.exe'
$lab = 'E:\StormMSN-Research\analysis\integrity'
$windowsPath = Join-Path $lab 'WLM2009-controlled-launch-windows.json'
$checker = Join-Path $lab 'Inspect-NativeWindows.ps1'
$before = @(Get-Process -Name msnmsgr -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
$started = Get-Date
$launched = $false
$launchError = $null
try {
  if (-not(Test-Path -LiteralPath $exe)) { throw 'Original executable missing' }
  Start-Process -FilePath $exe -ErrorAction Stop
  $launched = $true
} catch {
  $launchError = $_.Exception.GetType().Name
}
Start-Sleep -Seconds 6
$after = @(Get-Process -Name msnmsgr -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
$win = $null
$windowError = $null
try {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -NonInteractive -File $checker -OutputPath $windowsPath | Out-Null
  if (Test-Path -LiteralPath $windowsPath) {
    $win = Get-Content -LiteralPath $windowsPath -Raw -Encoding UTF8 | ConvertFrom-Json
  }
} catch { $windowError = $_.Exception.GetType().Name }
$crashes = @(
 Get-WinEvent -FilterHashtable @{
   LogName='Application';Id=1000;StartTime=$started.AddSeconds(-2)
 } -ErrorAction SilentlyContinue |
 Where-Object { $_.Message -match 'msnmsgr.exe' } |
 ForEach-Object {
   $x = [xml]$_.ToXml()
   $mod = $x.Event.EventData.Data | Where-Object { $_.Name -eq 'ModuleName' } | Select-Object -First 1
   [pscustomobject]@{time=$_.TimeCreated.ToString('o');module=[string]$mod.'#text'}
 }
)
$restored = $false
if ($after.Count -eq 0) {
  # Restore same /background startup if original exits during this test.
  Start-Process -FilePath $exe -ArgumentList '/background' -ErrorAction Stop
  Start-Sleep -Seconds 5
  $restored = (@(Get-Process msnmsgr -ErrorAction SilentlyContinue).Count -gt 0)
}
$visible = @()
if ($null -ne $win) {
  $visible = @($win.windows | Where-Object { $_.Visible -and $_.Width -ge 150 -and $_.Height -ge 150 })
}
$summary = [ordered]@{
  session = [Diagnostics.Process]::GetCurrentProcess().SessionId
  started = $started.ToString('o')
  pidBefore = @($before)
  launchInvoked = $launched
  launchErrorClass = $launchError
  pidAfter = @($after)
  windowsTotal = if ($null -ne $win) { [int]$win.windowCount } else { $null }
  visibleContentWindows = @($visible | Select-Object Class,X,Y,Width,Height,Dpi)
  windowInspectionError = $windowError
  newCrashEvents = @($crashes)
  backgroundRestoredAfterExit = $restored
  noCredentialsOrWindowTextCaptured = $true
}
[IO.File]::WriteAllText([IO.Path]::GetFullPath($Report),($summary|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
Write-Output ('SESSION='+$summary.session)
Write-Output ('STARTED='+$launched+' BEFORE='+@($before).Count+' AFTER='+@($after).Count)
Write-Output ('TOTAL_WINDOWS='+$summary.windowsTotal+' VISIBLE_UI='+$visible.Count)
foreach($w in $visible){Write-Output ('WINDOW '+$w.Class+' '+$w.Width+'x'+$w.Height+' DPI='+$w.Dpi)}
Write-Output ('NEW_CRASHES='+$crashes.Count+' RESTORED='+$restored)
