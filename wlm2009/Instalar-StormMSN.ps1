# Storm MSN -- instalador de conveniencia do Windows Live Messenger 2009 PT-BR
# Usa installer PRE-PATCHED oficial do Escargot, verifica SHA256 e configura
# os INIs do Switcher para os dominios privados do Storm MSN.
# O pacote nao redistribui o instalador proprietario da Microsoft.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$upstreamUrl = 'https://storage.levelleap.com/nina/clients/msnp/patched-installer/msn/escargot-wlm-14.0.8117.0416-pt-br.zip'
$upstreamHash = '4aa347b352dc33d4628c4e85bdf2e702e72aaaaf2fd86206f2611942ab72f2f0'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$me = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($me)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Solicitando permissao de Administrador...'
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $MyInvocation.MyCommand.Path + '"')
    )
    exit
}
Write-Host 'Storm MSN - Instalador do Windows Live Messenger 2009 PT-BR' -ForegroundColor Cyan
Write-Host 'Fonte original do instalador: Escargot / NINA.'
Write-Host 'Atenção: o cliente original utiliza protocolos legados. Use senha exclusiva.'
$pf86 = [Environment]::GetFolderPath('ProgramFilesX86')
if (-not $pf86) {$pf86 = $env:ProgramFiles}
$messenger = Join-Path $pf86 'Windows Live\Messenger\msnmsgr.exe'
$contacts = Join-Path $pf86 'Windows Live\Contacts\wlcomm.exe'
$msnIni = Join-Path $pf86 'Windows Live\Messenger\msnmsgr.exe-escargot.ini'
$contactsIni = Join-Path $pf86 'Windows Live\Contacts\wlcomm.exe-escargot.ini'
if ((Test-Path -LiteralPath $messenger) -and (Test-Path -LiteralPath $contacts) -and (
    -not (Test-Path -LiteralPath $msnIni) -or -not (Test-Path -LiteralPath $contactsIni)
)) {
    Write-Warning 'WLM 2009 UNPATCHED encontrado. Ele precisa da edicao pre-patcheada do Escargot para carregar a DLL do Switcher.'
    Write-Host 'Remova primeiro o Windows Live Messenger e Windows Live Contacts atuais em Aplicativos Instalados.'
    Write-Host 'Depois reinicie este assistente para instalar a versao pre-patcheada.'
    Read-Host 'Enter para encerrar'
    exit 2
}
if (-not (Test-Path -LiteralPath $messenger) -or -not (Test-Path -LiteralPath $contacts)) {
    $answer = Read-Host 'Instalar WLM 2009 pre-patcheado oficial? (S/N)'
    if ($answer -notmatch '^[sSyY]') { exit 1 }
    $temp = Join-Path $env:TEMP ('StormMSN-Instalacao-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    try {
        $file = Join-Path $temp 'escargot-wlm-2009-pt-br.zip'
        Write-Host 'Baixando o WLM 2009 da fonte oficial Escargot...'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $upstreamUrl -UseBasicParsing -OutFile $file
        $digest = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($digest -ne $upstreamHash) { throw ('Integridade falhou: '+$digest) }
        Expand-Archive -LiteralPath $file -DestinationPath $temp -Force
        $setup = Join-Path $temp 'escargot-wlm-14.0.8117.0416-pt-br.exe'
        if (-not (Test-Path -LiteralPath $setup)) { throw 'Instalador oficial nao encontrado no ZIP baixado.' }
        Write-Host 'Abrindo o instalador original. Conclua a instalacao do Messenger e Contacts.'
        $process = Start-Process -FilePath $setup -Wait -PassThru
        if ($process.ExitCode -ne 0) { Write-Warning ('O instalador retornou '+$process.ExitCode) }
        $upstreamPatcher = Join-Path $temp 'RUN_AFTER_INSTALL.exe'
        if (Test-Path -LiteralPath $upstreamPatcher) {
            Write-Host 'O pacote oficial inclui o utilitario RUN_AFTER_INSTALL.exe para ativar o Switcher no WLM.'
            $confirm = Read-Host 'Executar agora a ferramenta oficial de patch (clique PATCH ALL na janela)? (S/N)'
            if ($confirm -match '^[sSyY]') {
                Start-Process -FilePath $upstreamPatcher -Wait
            }
        }
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
if (-not (Test-Path -LiteralPath $messenger) -or -not (Test-Path -LiteralPath $contacts)) {
    throw 'O WLM 2009 e Contacts nao foram detectados. Confirme a instalacao e execute novamente.'
}
Write-Host 'Aplicando os dois INIs de configuracao para o Storm MSN...'
$configuration = Join-Path $scriptDir 'Configurar-StormMSN-WLM2009.ps1'
if (-not (Test-Path -LiteralPath $configuration)) { throw 'Script de configuracao do Switcher ausente.' }
& $configuration
Write-Host 'Instalacao/configuracao finalizadas.' -ForegroundColor Green
Write-Host 'Cadastro: https://msn.hoststorm.com.br/registrar'
Write-Host 'Servidor: im.hoststorm.com.br'
Read-Host 'Pressione Enter para encerrar'
