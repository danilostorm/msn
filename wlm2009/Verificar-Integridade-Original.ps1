# Storm MSN - Baseline imutavel da interface original do WLM 2009.
# SOMENTE LEITURA dos arquivos Microsoft. Nao injeta, nao corrige e nao redistribui DLLs.
[CmdletBinding()]
param(
    [ValidateSet('Capture','Verify')][string]$Mode = 'Verify',
    [string]$InstallRoot = (Join-Path $(if ([Environment]::GetFolderPath('ProgramFilesX86')) { [Environment]::GetFolderPath('ProgramFilesX86') } else { $env:ProgramFiles }) 'Windows Live'),
    [string]$BaselineFile = (Join-Path $env:LOCALAPPDATA 'StormMSN\WLM2009\integridade.json'),
    [switch]$Force
)
$ErrorActionPreference = 'Stop'

# Configuracao do Switcher (.ini) pode mudar o servidor. Os recursos visuais nao.
$protectedExtensions = @(
    '.exe', '.dll', '.thm', '.mui', '.ocx', '.ax', '.rll',
    '.bmp', '.png', '.gif', '.jpg', '.jpeg', '.ico', '.cur',
    '.xml', '.xsl', '.css', '.htm', '.html', '.wav', '.wma',
    '.swf', '.mct'
)
if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
    throw "Diretorio Windows Live inexistente: $InstallRoot"
}
$root = (Resolve-Path -LiteralPath $InstallRoot).ProviderPath.TrimEnd('\')
$expectedMessenger = Join-Path $root 'Messenger\msnmsgr.exe'
if (-not (Test-Path -LiteralPath $expectedMessenger -PathType Leaf)) {
    throw "Nao encontrei o Messenger original em: $expectedMessenger"
}
$baselinePath = [System.IO.Path]::GetFullPath($BaselineFile)
if ($baselinePath.StartsWith(($root + '\'), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Por seguranca, grave o manifesto FORA da pasta Windows Live.'
}

$files = @(
    Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction Stop |
        Where-Object {
            ($protectedExtensions -contains $_.Extension.ToLowerInvariant()) -and
            (($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0)
        } | Sort-Object FullName
)
if ($files.Count -eq 0) { throw 'Nenhum arquivo protegido encontrado.' }
$rows = @(
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($root.Length).TrimStart([char]'\').Replace('\','/')
        [pscustomobject][ordered]@{
            path = $relative
            size = [long]$file.Length
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
)
if ($Mode -eq 'Capture') {
    if ((Test-Path -LiteralPath $baselinePath) -and (-not $Force)) {
        throw "Ja existe um manifesto em $baselinePath. Para evitar substituir provas, escolha outro nome (ou confirme revisao e use -Force)."
    }
    $parent = Split-Path -Parent $baselinePath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $version = (Get-Item -LiteralPath $expectedMessenger).VersionInfo.FileVersion
    $snapshot = [pscustomobject][ordered]@{
        schema = 1
        createdUtc = (Get-Date).ToUniversalTime().ToString('o')
        originalClient = 'Windows Live Messenger 2009'
        messengerVersion = $version
        note = 'Hash local de referencia. Nao certifica autenticidade Microsoft; registra o estado presente nesta captura.'
        files = @($rows)
    }
    $json = $snapshot | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($baselinePath, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Output "BASELINE GERADA: $baselinePath | $($rows.Count) arquivos | Messenger $version"
    exit 0
}
if (-not (Test-Path -LiteralPath $baselinePath -PathType Leaf)) {
    throw "Baseline nao encontrada: $baselinePath. Primeiro execute -Mode Capture APENAS apos conferir a instalacao original."
}
$expected = Get-Content -LiteralPath $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($expected.schema -ne 1 -or $null -eq $expected.files) {
    throw 'Manifesto invalido ou versao de esquema nao suportada.'
}
$old = @{}
foreach ($row in @($expected.files)) {
    if ([string]::IsNullOrWhiteSpace([string]$row.path) -or $old.ContainsKey([string]$row.path)) {
        throw 'Manifesto contem caminhos duplicados ou invalidos.'
    }
    $old[[string]$row.path] = $row
}
$now = @{}
foreach ($row in $rows) { $now[[string]$row.path] = $row }
$differences = New-Object System.Collections.Generic.List[string]
foreach ($key in @($old.Keys | Sort-Object)) {
    if (-not $now.ContainsKey($key)) {
        $differences.Add("REMOVIDO $key")
    } elseif ($now[$key].sha256 -ne $old[$key].sha256 -or
              [long]$now[$key].size -ne [long]$old[$key].size) {
        $differences.Add("ALTERADO $key")
    }
}
foreach ($key in @($now.Keys | Sort-Object)) {
    if (-not $old.ContainsKey($key)) { $differences.Add("ADICIONADO $key") }
}
if ($differences.Count -gt 0) {
    $differences | ForEach-Object { Write-Output $_ }
    Write-Output "FALHA: $($differences.Count) diferencas de integridade. Verifique antes de usar ou alterar qualquer recurso."
    exit 2
}
Write-Output "OK: $($rows.Count) arquivos protegidos identicos ao baseline local. INIs do Switcher nao sao recursos visuais."
Write-Output 'IMPORTANTE: isto confirma hashes, NAO identidade pixel a pixel nem autenticidade do baseline.'
exit 0
