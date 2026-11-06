[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Reference,
    [Parameter(Mandatory = $true)][string]$Candidate,
    [string]$OutputDirectory = (Join-Path $env:TEMP 'StormMSN-PixelQA'),
    [ValidateRange(0, 255)][int]$Tolerance = 8
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$referencePath = (Resolve-Path -LiteralPath $Reference).Path
$candidatePath = (Resolve-Path -LiteralPath $Candidate).Path
New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
$a = [System.Drawing.Bitmap]::new($referencePath)
$b = [System.Drawing.Bitmap]::new($candidatePath)
$heat = $null
$overlay = $null
try {
    if ($a.Width -ne $b.Width -or $a.Height -ne $b.Height) {
        throw "As imagens devem ter a mesma resolução física. Original: $($a.Width)x$($a.Height); candidata: $($b.Width)x$($b.Height). Refaça as capturas a 100% (96 DPI), sem redimensionamento."
    }
    $heat = [System.Drawing.Bitmap]::new($a.Width, $a.Height)
    $overlay = [System.Drawing.Bitmap]::new($a.Width, $a.Height)
    [long]$sum = 0
    [long]$changed = 0
    for ($y = 0; $y -lt $a.Height; $y++) {
        for ($x = 0; $x -lt $a.Width; $x++) {
            $p = $a.GetPixel($x, $y)
            $q = $b.GetPixel($x, $y)
            [int]$dr = [Math]::Abs([int]$p.R - [int]$q.R)
            [int]$dg = [Math]::Abs([int]$p.G - [int]$q.G)
            [int]$db = [Math]::Abs([int]$p.B - [int]$q.B)
            $sum += $dr + $dg + $db
            if ([Math]::Max($dr, [Math]::Max($dg, $db)) -gt $Tolerance) { $changed++ }
            $heat.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(
                255, [int][Math]::Min(255, $dr * 4),
                [int][Math]::Min(255, $dg * 4), [int][Math]::Min(255, $db * 4)))
            $overlay.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(
                255, [int][Math]::Round(([int]$p.R + [int]$q.R) / 2),
                [int][Math]::Round(([int]$p.G + [int]$q.G) / 2),
                [int][Math]::Round(([int]$p.B + [int]$q.B) / 2)))
        }
    }
    $heatPath = Join-Path $OutputDirectory 'heatmap.png'
    $overlayPath = Join-Path $OutputDirectory 'overlay.png'
    $reportPath = Join-Path $OutputDirectory 'metrics.json'
    $heat.Save($heatPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $overlay.Save($overlayPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $pixels = [long]$a.Width * [long]$a.Height
    $metrics = [ordered]@{
        width = $a.Width
        height = $a.Height
        tolerance = $Tolerance
        mean_absolute_error = [Math]::Round($sum / ($pixels * 3.0), 4)
        changed_pixels = $changed
        changed_percent = [Math]::Round(100.0 * $changed / $pixels, 4)
        heatmap = $heatPath
        overlay = $overlayPath
    }
    $metrics | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    $metrics | Format-List | Out-String | Write-Output
    Write-Output "Relatório: $reportPath"
}
finally {
    $a.Dispose()
    $b.Dispose()
    if ($null -ne $heat) { $heat.Dispose() }
    if ($null -ne $overlay) { $overlay.Dispose() }
}
