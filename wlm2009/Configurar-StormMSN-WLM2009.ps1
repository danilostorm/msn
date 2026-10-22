# Storm MSN WLM 2009 -- install Switcher configuration in pre-patched WLM.
# Does not edit Windows hosts, trust root certificates, or replace MS binaries.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$nativeHost = 'im.hoststorm.com.br'
$httpsHost = 'msn.hoststorm.com.br'
Write-Host "Storm MSN - Configurar Windows Live Messenger 2009" -ForegroundColor Cyan

$pf86 = [Environment]::GetFolderPath('ProgramFilesX86')
if (-not $pf86) { $pf86 = $env:ProgramFiles }
$base = Join-Path $pf86 'Windows Live'
$exe = Join-Path $base 'Messenger\msnmsgr.exe'
$contactExe = Join-Path $base 'Contacts\wlcomm.exe'

if (-not (Test-Path -LiteralPath $exe)) {
  throw "Windows Live Messenger 2009 nao encontrado: $exe. Instale o WLM 2009 pre-patcheado."
}
if (-not (Test-Path -LiteralPath $contactExe)) {
  throw "Windows Live Contacts (wlcomm.exe) nao encontrado: $contactExe."
}
$running = @(Get-Process -Name 'msnmsgr','wlcomm' -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
  throw 'Feche MSN Messenger e Windows Live Contacts (incluindo bandeja) e tente novamente.'
}
$targets = @(
    (Join-Path $base 'Messenger\msnmsgr.exe-escargot.ini'),
    (Join-Path $base 'Contacts\wlcomm.exe-escargot.ini')
)
foreach ($path in $targets) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Arquivo Switcher ausente: $path. Instale a edicao pre-patcheada do Escargot."
  }
}
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($path in $targets) {
  $original = [System.IO.File]::ReadAllText($path)
  if ($original -notmatch '(?im)^\s*\[options\]\s*$') {
    throw "Secao [options] ausente em $path."
  }
  $lines = New-Object 'System.Collections.Generic.List[string]'
  $section = ''
  $seen = @{}
  $pairs = [ordered]@{
    type='msn'
    passporturls='1'
    server=$nativeHost
    configserver=$httpsHost
  }
  foreach ($lineOriginal in ($original -split "\r?\n")) {
    $line = $lineOriginal
    if ($line -match '^\s*\[(.+)\]\s*$') {
      if ($section -eq 'options') {
        foreach ($k in $pairs.Keys) {
          if (-not $seen.ContainsKey([string]$k)) { $lines.Add("$k = $($pairs[$k])") }
        }
      }
      $section = $Matches[1].ToLowerInvariant()
    }
    if ($section -eq 'options' -and $line -match '^\s*(type|passporturls|server|configserver)\s*=') {
      $key = $Matches[1].ToLowerInvariant()
      $line = "$key = $($pairs[$key])"
      $seen[$key] = $true
    }
    $lines.Add($line)
  }
  if ($section -eq 'options') {
    foreach ($k in $pairs.Keys) {
      if (-not $seen.ContainsKey([string]$k)) { $lines.Add("$k = $($pairs[$k])") }
    }
  }
  Copy-Item -LiteralPath $path -Destination "$path.storm-backup-$timestamp" -ErrorAction Stop
  [System.IO.File]::WriteAllText($path, [string]::Join([Environment]::NewLine, $lines), [System.Text.Encoding]::ASCII)
  Write-Host "Atualizado: $path" -ForegroundColor Green
}
Write-Host "Pronto. Servidor TCP: $nativeHost (1863/1864)" -ForegroundColor Green
Write-Host "Servicos HTTPS: $httpsHost" -ForegroundColor Green
Write-Host 'NENHUMA entrada HOSTS ou certificado raiz foi alterado.'
Write-Host 'Utilize uma conta propria temporaria para o primeiro teste.'
