// Storm MSN — isolated x86 Win32 host for WebView2 subwindow experiment.
// The only guest allowed is the executable created from StormWebView2EmbedGuest.cs
// next to this host. It DOES NOT attach to, inspect, reparent, or patch Messenger.
// Tests SetParent / WS_CHILD / sizing on two temporary owned lab processes.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

internal static class StormNativeEmbedHost {
    const int GWL_STYLE = -16;
    const int WS_CHILD = 0x40000000;
    const int WS_POPUP = unchecked((int)0x80000000);
    const int SWP_NOZORDER = 0x0004;
    const int SWP_FRAMECHANGED = 0x0020;
    const int SWP_SHOWWINDOW = 0x0040;
    const int WM_CLOSE = 0x0010;
    [DllImport("user32.dll", SetLastError=true)]
    private static extern IntPtr SetParent(IntPtr hWndChild, IntPtr newParent);
    [DllImport("user32.dll", SetLastError=true)]
    private static extern IntPtr GetParent(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError=true)]
    private static extern int GetWindowLong(IntPtr hWnd, int index);
    [DllImport("user32.dll", SetLastError=true)]
    private static extern int SetWindowLong(IntPtr hWnd, int index, int value);
    [DllImport("user32.dll", SetLastError=true)]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr after,
        int x, int y, int width, int height, int flags);
    [DllImport("user32.dll")]
    private static extern bool GetClientRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")]
    private static extern bool EnumWindows(WindowCallback cb, IntPtr lParam);
    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int max);
    [DllImport("user32.dll")]
    private static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr w, IntPtr l);
    private delegate bool WindowCallback(IntPtr hwnd, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)]
    private struct RECT {public int Left,Top,Right,Bottom;}

    private static Form host;
    private static Panel slot;
    private static Timer tick;
    private static Process guest;
    private static IntPtr guestHwnd;
    private static bool embedded;
    private static bool resizeTested;
    private static bool finished;
    private static Stopwatch clock;
    private static string reportFile, guestReportFile;
    private static string failure="";
    private static long embeddedAt;
    private static int slotWidthAtAttach, slotHeightAtAttach;

    [STAThread]
    public static void Main(string[] args) {
        string root=Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory);
        if (args.Length != 2 || args[0] != "--isolated-lab") return;
        reportFile = Path.GetFullPath(args[1]);
        if (!reportFile.StartsWith(root, StringComparison.OrdinalIgnoreCase)) return;
        string guestExe=Path.Combine(root, "StormWebView2EmbedGuest.exe");
        if(!File.Exists(guestExe)) {
            File.WriteAllText(reportFile, "State=GUEST_MISSING");
            return;
        }
        guestReportFile=Path.Combine(root,"EmbeddedGuestReport.txt");
        if(File.Exists(guestReportFile)) File.Delete(guestReportFile);
        if(File.Exists(reportFile)) File.Delete(reportFile);
        Application.EnableVisualStyles();
        host = new Form();
        host.Name = "StormMSNLaboratoryHost";
        host.Text = "Storm MSN LAB native hosting only";
        host.Width = 740;
        host.Height = 580;
        host.StartPosition = FormStartPosition.Manual;
        host.Location = new Point(-30000,-30000);
        host.ShowInTaskbar = false;
        host.FormBorderStyle = FormBorderStyle.FixedToolWindow;
        slot = new Panel();
        slot.Name="StormMSNLaboratorySlot";
        slot.Dock=DockStyle.Fill;
        host.Controls.Add(slot);
        slot.Resize += delegate { FitGuest(); };
        clock = Stopwatch.StartNew();
        tick = new Timer();
        tick.Interval=200;
        tick.Tick += Check;
        host.Shown += delegate {
            try {
                // Explicitly spawn an app with a fixed name within our lab folder.
                guest = new Process();
                guest.StartInfo.FileName = guestExe;
                guest.StartInfo.WorkingDirectory = root;
                guest.StartInfo.UseShellExecute = false;
                guest.StartInfo.Arguments = "--isolated-lab \"" + guestReportFile + "\"";
                guest.Start();
                tick.Start();
            } catch (Exception ex) {
                failure="START_"+ex.GetType().Name;
                Finish(failure);
            }
        };
        host.FormClosed += delegate { Cleanup(); };
        Application.Run(host);
    }
    private static void FitGuest() {
        if (!embedded || guestHwnd==IntPtr.Zero || slot.IsDisposed) return;
        SetWindowPos(guestHwnd,IntPtr.Zero,0,0,slot.ClientSize.Width,
                     slot.ClientSize.Height,SWP_NOZORDER|SWP_SHOWWINDOW);
    }
    private static IntPtr FindGuestWindow() {
        if(guest==null || guest.HasExited) return IntPtr.Zero;
        uint wanted = (uint)guest.Id;
        IntPtr found=IntPtr.Zero;
        EnumWindows(delegate(IntPtr hwnd,IntPtr user) {
            uint pid;
            GetWindowThreadProcessId(hwnd,out pid);
            if(pid != wanted) return true;
            StringBuilder title=new StringBuilder(200);
            GetWindowText(hwnd,title,title.Capacity);
            if(title.ToString()=="Storm MSN LAB guest WebView2") {
                found=hwnd; return false;
            }
            return true;
        },IntPtr.Zero);
        return found;
    }
    private static void Check(object sender,EventArgs e) {
        if (finished) return;
        if (clock.Elapsed.TotalSeconds > 31) {Finish("TIMEOUT");return;}
        if(guest!=null && guest.HasExited && !File.Exists(guestReportFile)) {
            Finish("GUEST_EXITED");return;
        }
        if(!embedded) {
            IntPtr hwnd=FindGuestWindow();
            if(hwnd!=IntPtr.Zero) {
                // NEVER accept any external HWND. This belongs to the child
                // process created by this lab program.
                guestHwnd=hwnd;
                int style=GetWindowLong(guestHwnd,GWL_STYLE);
                SetWindowLong(guestHwnd,GWL_STYLE,
                    (style & ~WS_POPUP)|WS_CHILD);
                SetParent(guestHwnd,slot.Handle);
                if(GetParent(guestHwnd)!=slot.Handle) {
                    Finish("SETPARENT_FAILED");return;
                }
                slotWidthAtAttach=slot.ClientSize.Width;
                slotHeightAtAttach=slot.ClientSize.Height;
                embedded=true;
                embeddedAt=clock.ElapsedMilliseconds;
                SetWindowPos(guestHwnd,IntPtr.Zero,0,0,
                    slotWidthAtAttach,slotHeightAtAttach,
                    SWP_NOZORDER|SWP_FRAMECHANGED|SWP_SHOWWINDOW);
            }
        }
        if(embedded && !resizeTested && clock.ElapsedMilliseconds-embeddedAt>350) {
            // Simulate a conversation activity panel being resized. The guest
            // must stay inside the same laboratory slot across that resize.
            host.Size = new Size(host.Width+96, host.Height+64);
            resizeTested=true;
            FitGuest();
        }
        if(embedded && resizeTested && File.Exists(guestReportFile)
           && clock.ElapsedMilliseconds-embeddedAt>1000) {
            Finish("RESULT_READY");
        }
    }
    private static void Finish(string reason) {
        if(finished) return;
        finished=true;
        try { tick.Stop(); }catch{}
        bool verified=embedded && guestHwnd!=IntPtr.Zero &&
                      GetParent(guestHwnd)==slot.Handle;
        RECT rect=new RECT();
        bool validRect=(guestHwnd!=IntPtr.Zero) &&
                        GetClientRect(guestHwnd,out rect);
        int childWidth=validRect ? rect.Right-rect.Left : 0;
        int childHeight=validRect ? rect.Bottom-rect.Top : 0;
        bool childSizeMatchesSlot = validRect &&
             childWidth == slot.ClientSize.Width &&
             childHeight == slot.ClientSize.Height;
        bool loaded=false, wasm=false, wasmInstantiated=false, webgl=false;
        if(File.Exists(guestReportFile)) {
            string data=File.ReadAllText(guestReportFile);
            loaded=data.Contains("State=OK");
            wasm=data.Contains("\\\"wasm\\\":\\\"object\\\"");
            wasmInstantiated=data.Contains("\\\"wasmInstantiate\\\":true");
            webgl=data.Contains("\\\"webgl\\\":true");
            // Keep reports small, no page DOM/text/credentials.
        }
        List<string> lines=new List<string>();
        lines.Add("State="+reason);
        lines.Add("LabOnly=true");
        lines.Add("OriginalMessengerTouched=false");
        lines.Add("GuestSpawnedFromLab="+(guest!=null));
        lines.Add("ReparentVerified="+verified);
        lines.Add("GuestId="+(guest!=null ? guest.Id.ToString():"none"));
        lines.Add("ParentHandle=0x"+slot.Handle.ToInt64().ToString("x"));
        lines.Add("AttachedGuestHandle=0x"+guestHwnd.ToInt64().ToString("x"));
        lines.Add("TargetWidth="+slotWidthAtAttach);
        lines.Add("TargetHeight="+slotHeightAtAttach);
        lines.Add("ResizeTested="+resizeTested);
        lines.Add("SlotWidthAfterResize="+slot.ClientSize.Width);
        lines.Add("SlotHeightAfterResize="+slot.ClientSize.Height);
        lines.Add("ChildWidthAfterResize="+childWidth);
        lines.Add("ChildHeightAfterResize="+childHeight);
        lines.Add("ChildSizeMatchesSlot="+childSizeMatchesSlot);
        lines.Add("GuestClientRectReadable="+validRect);
        lines.Add("WebView2PageLoaded="+loaded);
        lines.Add("WebAssemblyReported="+wasm);
        lines.Add("WebAssemblyInstantiated="+wasmInstantiated);
        lines.Add("WebGLContextAvailable="+webgl);
        lines.Add("ElapsedMs="+clock.ElapsedMilliseconds);
        lines.Add("OriginalGameExecuted=false");
        try{File.WriteAllLines(reportFile,lines.ToArray());}catch{}
        try{host.Close();}catch{}
    }
    private static void Cleanup() {
        try{tick.Stop();tick.Dispose();}catch{}
        if(guest==null) return;
        try {
            if (!guest.HasExited && guestHwnd!=IntPtr.Zero)
                PostMessage(guestHwnd,WM_CLOSE,IntPtr.Zero,IntPtr.Zero);
            if(!guest.HasExited && !guest.WaitForExit(4000)) guest.Kill();
        }catch{}
        try{guest.Dispose();}catch{}
    }
}
