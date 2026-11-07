# Storm MSN — abrir EXCLUSIVAMENTE o Windows Live Messenger 2009 original.
# Nao cria UI, nao copia DLL, nao altera arquivos, registro, hosts ou certificados.
[CmdletBinding()]
param([switch]$CheckOnly)
$ErrorActionPreference='Stop'
$root=[Environment]::GetFolderPath('ProgramFilesX86')
if (-not $root) { $root=$env:ProgramFiles }
$wl=Join-Path $root 'Windows Live'
$exe=Join-Path $wl 'Messenger\msnmsgr.exe'
$required=@(
  $exe,
  (Join-Path $wl 'Messenger\uxcore.dll'),
  (Join-Path $wl 'Messenger\msgsres.dll'),
  (Join-Path $wl 'Messenger\msgrvsta.thm'),
  (Join-Path $wl 'Contacts\wlcomm.exe'),
  (Join-Path $wl 'Messenger\escargot.dll'),
  (Join-Path $wl 'Contacts\escargot.dll')
)
foreach($p in $required){
  if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Arquivo original/compatibilidade ausente: $p"}
}
$version=(Get-Item -LiteralPath $exe).VersionInfo.FileVersion
if($version -ne '14.0.8117.0416'){throw "Versao diferente do WLM 2009 PT-BR esperado: $version"}
foreach($name in @('Messenger\msnmsgr.exe-escargot.ini','Contacts\wlcomm.exe-escargot.ini')){
  $path=Join-Path $wl $name
  if(-not(Test-Path -LiteralPath $path)){throw "INI do Switcher ausente: $path"}
  $content=Get-Content -LiteralPath $path -Encoding ASCII -Raw
  $expected=@{
    type='msn'
    passporturls='1'
    server='im.hoststorm.com.br'
    configserver='msn.hoststorm.com.br'
  }
  $values=@{}
  $section=''
  foreach($line in ($content -split '\r?\n')){
    if($line -match '^\s*\[(.*?)\]\s*$'){$section=$Matches[1].ToLowerInvariant();continue}
    if($section -eq 'options' -and $line -match '^\s*([a-zA-Z]+)\s*=\s*([^;#\r\n]+)'){
      $values[$Matches[1].ToLowerInvariant()]=$Matches[2].Trim()
    }
  }
  foreach($key in $expected.Keys){
    if((-not $values.ContainsKey($key)) -or
        ($values[$key] -ine $expected[$key])){
      throw "Switcher '$name': $key nao aponta para a configuracao Storm MSN. Execute o configurador oficial antes de abrir."
    }
  }
}
Write-Output "STORM_WLM_ORIGINAL_OK version=$version server=im.hoststorm.com.br"
if($CheckOnly){
  Write-Output 'CheckOnly: nenhum processo foi iniciado.'
  exit 0
}
if([Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0){
  throw 'Abra o Messenger na sessao grafica do Windows, nao pelo servico SSH (sessao 0).'
}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=New-Object Security.Principal.WindowsPrincipal($identity)
if($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
  throw 'Nao inicie o WLM 2009 elevado. Abra este script normalmente, sem Executar como administrador.'
}
Start-Process -FilePath $exe -ErrorAction Stop
Write-Output 'Iniciador chamou apenas o msnmsgr.exe original, sem alterar sua interface.'
