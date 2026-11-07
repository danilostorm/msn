# Storm MSN (WLM 2009) — per-user Edge/WebView2 game protocol.
# Register ONLY a new stormmsn-game:// scheme. Never alter the Windows default
# HTTP/HTTPS browser, Microsoft Messenger binaries, COM or system-wide HKLM.
# The receiver validates numeric game IDs and PlayStor navigation internally.
[CmdletBinding()]
param(
    [ValidateSet('Install','Verify','Uninstall')]
    [string]$Action='Verify',
    [string]$Launcher='E:\StormMSN-Research\lab-native-2009\webview2-poc\build\StormEdgePlaystorLauncher.exe'
)
$ErrorActionPreference='Stop'
$lab='E:\StormMSN-Research\lab-native-2009\'
$exe=[IO.Path]::GetFullPath($Launcher)
if(-not $exe.StartsWith($lab,[StringComparison]::OrdinalIgnoreCase) -or
   -not $exe.EndsWith('\StormEdgePlaystorLauncher.exe',[StringComparison]::OrdinalIgnoreCase)) {
    throw 'Launcher path is outside the isolated Storm MSN Edge lab'
}
if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){
    throw 'Edge-only laboratory launcher missing'
}
$base='HKCU:\Software\Classes\stormmsn-game'
$commandPath="$base\shell\open\command"
$expectedCommand='"'+$exe+'" --uri "%1"'
function Get-RegisteredCommand {
    if(-not(Test-Path -LiteralPath $commandPath)){return $null}
    return (Get-Item -LiteralPath $commandPath).GetValue('')
}
$actual=Get-RegisteredCommand
switch($Action) {
    'Verify' {
        $root=if(Test-Path -LiteralPath $base){Get-Item -LiteralPath $base}else{$null}
        $schemeEnabled=($null -ne $root) -and ($null -ne $root.GetValue('URL Protocol'))
        $valid=($actual -ceq $expectedCommand) -and $schemeEnabled
        Write-Output ('STORM_EDGE_SCHEME_INSTALLED='+$valid)
        Write-Output ('DEFAULT_HTTP_BROWSER_UNCHANGED=true')
        Write-Output ('SCHEME=stormmsn-game')
        Write-Output ('EXECUTABLE_SHA256='+((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()))
        if(-not $valid){exit 1}
        break
    }
    'Install' {
        if($null -ne $actual -and $actual -cne $expectedCommand) {
            throw 'Another stormmsn-game handler exists; refusing to overwrite.'
        }
        New-Item -Path $base -Value 'URL:Storm MSN PlayStor Edge Game' -Force|Out-Null
        New-ItemProperty -Path $base -Name 'URL Protocol' -Value '' -PropertyType String -Force |Out-Null
        New-Item -Path "$base\DefaultIcon" -Value ('"'+$exe+'",0') -Force|Out-Null
        New-Item -Path $commandPath -Value $expectedCommand -Force|Out-Null
        if((Get-RegisteredCommand) -cne $expectedCommand){
            throw 'Protocol handler verification failed.'
        }
        Write-Output 'STORM_EDGE_SCHEME_INSTALLED=true'
        Write-Output 'DEFAULT_HTTP_BROWSER_UNCHANGED=true'
        Write-Output 'GAME_DEEPLINK=stormmsn-game://play/673'
        break
    }
    'Uninstall' {
        if($null -eq $actual){
            Write-Output 'STORM_EDGE_SCHEME_INSTALLED=false'
            break
        }
        if($actual -cne $expectedCommand){
            throw 'Registered protocol belongs to another executable; refusing removal.'
        }
        Remove-Item -LiteralPath $base -Recurse -Force
        Write-Output 'STORM_EDGE_SCHEME_INSTALLED=false'
        Write-Output 'DEFAULT_HTTP_BROWSER_UNCHANGED=true'
        break
    }
}
