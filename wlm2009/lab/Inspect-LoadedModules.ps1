# Inventario apenas dos modulos nativos carregados pelo Messenger.
# Execute no PowerShell x86, para enumerar corretamente um processo de 32 bits.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
foreach($p in @(Get-Process -Name msnmsgr,wlcomm -ErrorAction SilentlyContinue)){
    Write-Output ('PROCESS '+$p.ProcessName+' PID='+$p.Id+' SESSION='+$p.SessionId)
    try {
      $modules = @($p.Modules)
      Write-Output ('MODULE_COUNT='+$modules.Count)
      foreach($m in $modules){
        if($m.ModuleName -match '^(msnmsgr|wlcomm|uxcore|msgsres|wldlog|msidcrl|msgslang|msgrvsta)|messengerplus|escargot|msgrapp|msncore'){
          $path = [string]$m.FileName
          $hash = if(Test-Path -LiteralPath $path -PathType Leaf){(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()}else{'missing'}
          Write-Output ($m.ModuleName+' | '+$path+' | SHA256='+$hash)
        }
      }
    } catch {Write-Output ('MODULE_ENUMERATION_FAILED '+$_.Exception.GetType().Name)}
}
