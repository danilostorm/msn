# Janela nativa do WLM 2009: diagnostico somente leitura.
# Nao captura pixels/texto/credenciais e nao interage com janelas.
[CmdletBinding()]
param([string]$OutputPath = 'E:\StormMSN-Research\analysis\integrity\WLM2009-window-diagnostics.json')
$ErrorActionPreference = 'Stop'
$native = @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class WlmNativeWindows {
    [StructLayout(LayoutKind.Sequential)] public struct RECT {
      public int Left, Top, Right, Bottom;
    }
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr data);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder className, int length);
    [DllImport("user32.dll", EntryPoint="GetWindowLongW")] public static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hWnd);
    public class WindowInfo {
      public string Handle;
      public uint ProcessId;
      public string Class;
      public bool Visible, Minimized;
      public int X,Y,Width,Height;
      public string Style;
      public uint Dpi;
    }
    public static List<WindowInfo> Scan(uint[] pids) {
      HashSet<uint> wanted = new HashSet<uint>(pids);
      List<WindowInfo> found = new List<WindowInfo>();
      EnumWindows((hwnd, extra) => {
        uint pid; GetWindowThreadProcessId(hwnd, out pid);
        if (!wanted.Contains(pid)) return true;
        StringBuilder name = new StringBuilder(256);
        GetClassName(hwnd, name, name.Capacity);
        RECT rect;
        GetWindowRect(hwnd, out rect);
        int style = GetWindowLong(hwnd, -16);
        uint dpi = 0;
        try { dpi = GetDpiForWindow(hwnd); } catch {}
        found.Add(new WindowInfo() {
           Handle = "0x" + hwnd.ToInt64().ToString("x"),
           ProcessId = pid, Class = name.ToString(),
           Visible = IsWindowVisible(hwnd), Minimized = IsIconic(hwnd),
           X = rect.Left, Y = rect.Top,
           Width = rect.Right-rect.Left, Height = rect.Bottom-rect.Top,
           Style = "0x" + style.ToString("x8"), Dpi = dpi
        });
        return true;
      }, IntPtr.Zero);
      return found;
    }
}
'@
Add-Type -TypeDefinition $native -Language CSharp
$pids = @(Get-Process -Name msnmsgr, wlcomm -ErrorAction SilentlyContinue | ForEach-Object { [uint32]$_.Id })
$windows = @([WlmNativeWindows]::Scan([uint32[]]$pids) | Sort-Object ProcessId,Handle)
$out = [ordered]@{
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    executionSession = [Diagnostics.Process]::GetCurrentProcess().SessionId
    user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    desktopWidth = [WlmNativeWindows]::GetSystemMetrics(0)
    desktopHeight = [WlmNativeWindows]::GetSystemMetrics(1)
    processes = @($pids)
    windowCount = $windows.Count
    windows = @($windows)
    limitation = 'EnumWindows is scoped to the current graphical session. No window text or pixels captured.'
}
$target = [IO.Path]::GetFullPath($OutputPath)
if (-not (Test-Path -LiteralPath (Split-Path -Parent $target))) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
}
$json = $out | ConvertTo-Json -Depth 7
[IO.File]::WriteAllText($target,$json,[Text.UTF8Encoding]::new($false))
Write-Output ('SESSION='+$out.executionSession+' WINDOWS='+$out.windowCount+' OUTPUT='+$target)
foreach ($w in $windows) {
    Write-Output ('PID='+$w.ProcessId+' HANDLE='+$w.Handle+' CLASS='+$w.Class+' VISIBLE='+$w.Visible+' MINIMIZED='+$w.Minimized+' RECT='+$w.X+','+$w.Y+','+$w.Width+'x'+$w.Height+' DPI='+$w.Dpi)
}
