# Teste sem binarios Microsoft, usando arquivos sinteticos isolados no TEMP.
$ErrorActionPreference = 'Stop'
$tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'Verificar-Integridade-Original.ps1'
$work = Join-Path $env:TEMP ('StormMSN-Audit-Test-' + [guid]::NewGuid().ToString('N'))
$root = Join-Path $work 'Windows Live'
$messenger = Join-Path $root 'Messenger'
$contacts = Join-Path $root 'Contacts'
$baseline = Join-Path $work 'baseline.json'

function Assert-Code([int]$expected, [string]$context) {
    if ($LASTEXITCODE -ne $expected) {
        throw "$context : codigo esperado $expected, recebido $LASTEXITCODE"
    }
}
function Invoke-Check([string]$mode, [int]$expected) {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -Mode $mode -InstallRoot $root -BaselineFile $baseline 2>&1
    Assert-Code $expected $mode
    Write-Output ("$mode esperado=$expected : " + (($output | Out-String).Trim() -replace "[\r\n]+", ' | '))
}

try {
    New-Item -ItemType Directory -Path $messenger, $contacts -Force | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $messenger 'msnmsgr.exe'), [byte[]]@(1,2,3,4))
    [IO.File]::WriteAllBytes((Join-Path $messenger 'msgsres.dll'), [byte[]]@(15,16,17))
    Set-Content -LiteralPath (Join-Path $messenger 'msnmsgr.exe-escargot.ini') -Value 'server = example.invalid' -Encoding ASCII
    Invoke-Check 'Capture' 0
    $manifest = Get-Content -LiteralPath $baseline -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.files.Count -ne 2) { throw 'Baseline deveria listar somente os dois recursos protegidos.' }
    Invoke-Check 'Capture' 1 # Impede sobregravar prova
    Invoke-Check 'Verify' 0
    Set-Content -LiteralPath (Join-Path $messenger 'msnmsgr.exe-escargot.ini') -Value 'server = novo.example.invalid' -Encoding ASCII
    Invoke-Check 'Verify' 0 # Switcher INI nao muda os arquivos originais
    [IO.File]::WriteAllBytes((Join-Path $messenger 'msgsres.dll'), [byte[]]@(15,16,99))
    Invoke-Check 'Verify' 2 # Detecta mutacao de recurso
    [IO.File]::WriteAllBytes((Join-Path $messenger 'msgsres.dll'), [byte[]]@(15,16,17))
    Remove-Item -LiteralPath (Join-Path $messenger 'msgsres.dll')
    Invoke-Check 'Verify' 2 # Detecta recurso ausente
    [IO.File]::WriteAllBytes((Join-Path $messenger 'msgsres.dll'), [byte[]]@(15,16,17))
    [IO.File]::WriteAllBytes((Join-Path $contacts 'wlcomm.exe'), [byte[]]@(8,9))
    Invoke-Check 'Verify' 2 # Detecta recurso adicional
    Remove-Item -LiteralPath (Join-Path $contacts 'wlcomm.exe')
    Invoke-Check 'Verify' 0 # Recuperacao
    Write-Output 'TODOS OS TESTES PASSARAM.'
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
