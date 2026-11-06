[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProcessName,
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class StormWindowCapture {
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")]
    public static extern uint GetDpiForWindow(IntPtr hwnd);
}
'@
$name = [System.IO.Path]::GetFileNameWithoutExtension($ProcessName)
$matches = @(Get-Process -Name $name -ErrorAction Stop | Where-Object {
    $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle.Length -gt 0
})
if ($matches.Count -ne 1) {
    throw "Esperado exatamente 1 processo '$name' com janela visível; encontrados $($matches.Count). Execute na sessão de trabalho do Windows (não em serviço/SSH) e feche as janelas extras."
}
$p = $matches[0]
$rect = New-Object StormWindowCapture+Rect
if (-not [StormWindowCapture]::GetWindowRect($p.MainWindowHandle, [ref]$rect)) {
    throw "GetWindowRect falhou para a janela $($p.MainWindowTitle)."
}
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
if ($w -le 0 -or $h -le 0) { throw "Janela minimizada ou dimensões inválidas." }
$dpi = [StormWindowCapture]::GetDpiForWindow($p.MainWindowHandle)
if ($dpi -ne 96) {
    Write-Warning "A janela está em $dpi DPI, não 96. Use 100% de escala para comparar pixel por pixel."
}
$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }
$image = [System.Drawing.Bitmap]::new($w, $h)
$graphics = [System.Drawing.Graphics]::FromImage($image)
try {
    # CopyFromScreen captures the visible desktop, not an off-screen render.
    # Bring the target window forward manually and ensure nothing overlaps.
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, [System.Drawing.Size]::new($w, $h))
    $image.Save([System.IO.Path]::GetFullPath($OutputPath), [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "$($p.MainWindowTitle) | $w x $h | DPI=$dpi | $OutputPath"
}
finally {
    $graphics.Dispose()
    $image.Dispose()
}
