# Storm MSN / WLM2009 — read-only HWND geometry inspector.
# Run in the interactive session as the desktop user, not in SSH session 0.
# Does not capture text, screenshots, contacts, URLs, clipboard, input or credentials.
[CmdletBinding()]
param([string]$OutputPath = 'E:\StormMSN-Research\analysis\integrity\WLM2009-window-tree.json')

$ErrorActionPreference = 'Stop'
$native = @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class WlmWindowTree {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {public int Left, Top, Right, Bottom;}
    public delegate bool EnumCallback(IntPtr hwnd,IntPtr user);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumCallback proc,IntPtr data);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent,EnumCallback proc,IntPtr data);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd,out RECT rect);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd,StringBuilder sb,int max);
    [DllImport("user32.dll",EntryPoint="GetWindowLongW")] public static extern int GetWindowLong(IntPtr hwnd,int index);
    public class Row {
        public string Handle,Parent,Class,Style;
        public uint PID;
        public int Depth,X,Y,Width,Height;
        public bool Visible;
    }
    public static List<Row> Inspect(uint[] pids,int max) {
        HashSet<uint> wanted = new HashSet<uint>(pids);
        List<Row> rows = new List<Row>();
        HashSet<long> seen = new HashSet<long>();
        Action<IntPtr,int> add=(hwnd,depth)=>{
            if(rows.Count>=max || !seen.Add(hwnd.ToInt64()))return;
            uint pid;GetWindowThreadProcessId(hwnd,out pid);
            if(!wanted.Contains(pid))return;
            RECT r; GetWindowRect(hwnd,out r);
            StringBuilder clazz=new StringBuilder(260);
            GetClassName(hwnd,clazz,clazz.Capacity);
            rows.Add(new Row{
                Handle="0x"+hwnd.ToInt64().ToString("x"),
                Parent="0x"+GetParent(hwnd).ToInt64().ToString("x"),
                Class=clazz.ToString(),PID=pid,Depth=depth,
                X=r.Left,Y=r.Top,Width=r.Right-r.Left,Height=r.Bottom-r.Top,
                Visible=IsWindowVisible(hwnd),
                Style="0x"+GetWindowLong(hwnd,-16).ToString("x8")
            });
        };
        EnumWindows((hwnd,extra)=>{
            uint pid;GetWindowThreadProcessId(hwnd,out pid);
            if(!wanted.Contains(pid))return true;
            add(hwnd,0);
            EnumChildWindows(hwnd,(child,unused)=>{
                add(child,1);
                return rows.Count<max;
            },IntPtr.Zero);
            return rows.Count<max;
        },IntPtr.Zero);
        return rows;
    }
}
'@
Add-Type -TypeDefinition $native -Language CSharp
$pids=@(Get-Process -Name msnmsgr,wlcomm -ErrorAction SilentlyContinue |
        ForEach-Object { [uint32]$_.Id })
$tree=@([WlmWindowTree]::Inspect([uint32[]]$pids,320))
$root=@($tree | Where-Object {$_.Depth -eq 0 -and $_.Class -eq 'MSBLWindowClass'})
$visible=@($root | Where-Object {$_.Visible -and $_.Width -gt 150 -and $_.Height -gt 150})
$report=[ordered]@{
    UTC=(Get-Date).ToUniversalTime().ToString('o')
    Session=[Diagnostics.Process]::GetCurrentProcess().SessionId
    ProcessIds=@($pids)
    TotalWindowNodes=$tree.Count
    TopLevelNativeWindowCount=$root.Count
    VisibleNativeWindowCount=$visible.Count
    ConversationCandidateExists=($visible.Count -gt 0 -and
                                    (@($visible|Where-Object {$_.Width -gt 400}).Count -gt 0))
    SafeToAttachWebView2=$false
    Reason='No DirectUI activity-host rectangle has been verified. Never attach to MSBLWindowClass root.'
    HWNDTree=@($tree)
    Collected='Win32 classes, HWNDs, geometry, visibility only. NO text, pixel data, credentials.'
}
$target=[IO.Path]::GetFullPath($OutputPath)
$dir=Split-Path -Parent $target
if(-not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
[IO.File]::WriteAllText($target,($report|ConvertTo-Json -Depth 7),
    [Text.UTF8Encoding]::new($false))
Write-Output ('SESSION='+$report.Session+
   ' WINDOW_NODES='+$report.TotalWindowNodes+
   ' WLM_TOPLEVEL='+$report.TopLevelNativeWindowCount+
   ' VISIBLE_NATIVE='+$report.VisibleNativeWindowCount+
   ' CONVERSATION_CANDIDATE='+$report.ConversationCandidateExists)
foreach($node in $tree | Where-Object {$_.Visible -and $_.Width -gt 120 -and $_.Height -gt 90} | Select-Object -First 22){
  Write-Output ('PID='+$node.PID+' HWND='+$node.Handle+' CLASS='+$node.Class+
       ' DEPTH='+$node.Depth+' RECT='+$node.X+','+$node.Y+','+$node.Width+'x'+$node.Height)
}
Write-Output ('WEBVIEW_ATTACH_ALLOWED='+$report.SafeToAttachWebView2)
