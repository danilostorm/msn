// Storm MSN: x86 LAB-ONLY prototype embedding a WebView2 child into a
// genuine Trident "Internet Explorer_Server" HWND hosted by a separate
// Windows Forms WebBrowser. NO Messenger handles/binaries are touched.
using System;
using System.IO;
using System.Drawing;
using System.Diagnostics;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Forms;

internal static class StormTridentGameHost {
    private const string PublicCatalog =
      "https://msn.hoststorm.com.br/AppDirectory/Directory.aspx?from=wlm2009";
    const int GWL_STYLE=-16;
    const int WS_CHILD=0x40000000;
    const int WS_POPUP=unchecked((int)0x80000000);
    const int SWP_NOZORDER=0x0004,SWP_FRAMECHANGED=0x0020,SWP_SHOWWINDOW=0x0040;
    const uint WM_CLOSE=0x0010;
    [DllImport("user32.dll")] static extern bool EnumWindows(Callback callback,IntPtr data);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr hwnd,Callback callback,IntPtr data);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)]
    static extern int GetClassName(IntPtr hwnd,StringBuilder name,int cap);
    [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr hwnd);
    [DllImport("user32.dll",SetLastError=true)] static extern IntPtr SetParent(IntPtr hwnd,IntPtr newParent);
    [DllImport("user32.dll",EntryPoint="GetWindowLongW")]
    static extern int GetWindowLong(IntPtr hwnd,int index);
    [DllImport("user32.dll",EntryPoint="SetWindowLongW")]
    static extern int SetWindowLong(IntPtr hwnd,int index,int value);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hwnd,IntPtr after,int x,int y,int w,int h,int flags);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr hwnd,out RECT rect);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr hwnd,uint msg,IntPtr w,IntPtr l);
    delegate bool Callback(IntPtr hwnd,IntPtr data);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left,Top,Right,Bottom; }

    static Form host;
    static WebBrowser trident;
    static Timer monitor;
    static Process guest;
    static IntPtr ieHwnd,guestHwnd;
    static string output,guestOutput;
    static Stopwatch elapsed;
    static bool navigated,embedded,resized,completed;
    static string error="";
    static int initialWidth,initialHeight;
    static long attachMs;

    [STAThread]
    static void Main(string[] args) {
        string directory=Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory);
        if(args.Length!=2 || args[0]!="--isolated-lab") return;
        output=Path.GetFullPath(args[1]);
        if(!output.StartsWith(directory,StringComparison.OrdinalIgnoreCase)) return;
        string childExe=Path.Combine(directory,"StormPlaystorGameProbe.exe");
        if(!File.Exists(childExe)) {
            File.WriteAllText(output,"State=GUEST_MISSING");return;
        }
        guestOutput=Path.Combine(directory,"TridentEmbeddedGameGuestReport.txt");
        if(File.Exists(output))File.Delete(output);
        if(File.Exists(guestOutput))File.Delete(guestOutput);
        Application.EnableVisualStyles();
        host=new Form();
        host.Text="Storm MSN isolated Trident child host";
        host.Name="StormTridentGameHost";
        host.Size=new Size(840,630);
        host.StartPosition=FormStartPosition.Manual;
        host.Location=new Point(-30000,-30000);
        host.ShowInTaskbar=false;
        host.FormBorderStyle=FormBorderStyle.FixedToolWindow;
        trident=new WebBrowser();
        trident.Dock=DockStyle.Fill;
        trident.ScriptErrorsSuppressed=true;
        trident.AllowWebBrowserDrop=false;
        trident.WebBrowserShortcutsEnabled=false;
        trident.IsWebBrowserContextMenuEnabled=false;
        trident.NewWindow+=delegate(object sender,System.ComponentModel.CancelEventArgs e){e.Cancel=true;};
        trident.Navigating+=delegate(object sender,WebBrowserNavigatingEventArgs e){
            if(e.Url == null || !string.Equals(e.Url.AbsoluteUri,PublicCatalog,StringComparison.OrdinalIgnoreCase))e.Cancel=true;
        };
        trident.DocumentCompleted+=delegate(object sender,WebBrowserDocumentCompletedEventArgs e){
            if(trident.ReadyState==WebBrowserReadyState.Complete &&
                trident.Url!=null && trident.Url.AbsoluteUri==PublicCatalog) navigated=true;
        };
        host.Controls.Add(trident);
        elapsed=Stopwatch.StartNew();
        monitor=new Timer();
        monitor.Interval=150;
        monitor.Tick+=OnTick;
        host.Shown+=delegate {
            try {trident.Navigate(PublicCatalog);monitor.Start();}
            catch(Exception ex){Finish("LEGACY_NAV_"+ex.GetType().Name);}
        };
        host.FormClosed+=delegate{Cleanup();};
        Application.Run(host);
    }

    static IntPtr LocateIE() {
        IntPtr found=IntPtr.Zero;
        EnumChildWindows(trident.Handle,delegate(IntPtr hwnd,IntPtr ctx){
            StringBuilder name=new StringBuilder(180);
            GetClassName(hwnd,name,name.Capacity);
            uint owner;GetWindowThreadProcessId(hwnd,out owner);
            if(name.ToString()=="Internet Explorer_Server" &&
               owner == (uint)Process.GetCurrentProcess().Id) {
                found=hwnd;return false;
            }
            return true;
        },IntPtr.Zero);
        return found;
    }
    static IntPtr LocateGuest() {
        if(guest==null || guest.HasExited)return IntPtr.Zero;
        IntPtr found=IntPtr.Zero;
        EnumWindows(delegate(IntPtr hwnd,IntPtr ctx){
            uint owner;GetWindowThreadProcessId(hwnd,out owner);
            if(owner!=(uint)guest.Id)return true;
            StringBuilder name=new StringBuilder(180);
            GetClassName(hwnd,name,name.Capacity);
            if(name.ToString()=="WindowsForms10.Window.8.app.0.141b42a_r8_ad1" ||
               name.ToString().StartsWith("WindowsForms10.Window.",StringComparison.Ordinal)){
                found=hwnd;return false;
            }
            return true;
        },IntPtr.Zero);
        return found;
    }
    static bool Fit() {
        if(!embedded || ieHwnd==IntPtr.Zero || guestHwnd==IntPtr.Zero)return false;
        RECT r;
        if(!GetClientRect(ieHwnd,out r))return false;
        int width=r.Right-r.Left,height=r.Bottom-r.Top;
        return width>100 && height>100 &&
            SetWindowPos(guestHwnd,IntPtr.Zero,0,0,width,height,
                         SWP_NOZORDER|SWP_SHOWWINDOW);
    }
    static void OnTick(object sender,EventArgs e) {
        if(completed)return;
        if(elapsed.Elapsed.TotalSeconds>32) {Finish("TIMEOUT");return;}
        if(!navigated)return;
        if(ieHwnd==IntPtr.Zero) {
            ieHwnd=LocateIE();
            if(ieHwnd==IntPtr.Zero)return;
        }
        if(guest==null) {
            guest=new Process();
            guest.StartInfo.FileName=Path.Combine(
                AppDomain.CurrentDomain.BaseDirectory,"StormPlaystorGameProbe.exe");
            guest.StartInfo.WorkingDirectory=AppDomain.CurrentDomain.BaseDirectory;
            guest.StartInfo.Arguments="--isolated-lab \""+guestOutput+"\"";
            guest.StartInfo.UseShellExecute=false;
            try{guest.Start();}catch(Exception ex){Finish("SPAWN_"+ex.GetType().Name);}
            return;
        }
        if(guest.HasExited && !File.Exists(guestOutput)) {
            Finish("GUEST_EXITED");return;
        }
        if(!embedded) {
            IntPtr top=LocateGuest();
            if(top==IntPtr.Zero)return;
            guestHwnd=top;
            int style=GetWindowLong(top,GWL_STYLE);
            SetWindowLong(top,GWL_STYLE,(style & ~WS_POPUP)|WS_CHILD);
            SetParent(top,ieHwnd);
            if(GetParent(top)!=ieHwnd) {Finish("ATTACH_REJECTED");return;}
            embedded=true;
            attachMs=elapsed.ElapsedMilliseconds;
            RECT size;
            GetClientRect(ieHwnd,out size);
            initialWidth=size.Right-size.Left;
            initialHeight=size.Bottom-size.Top;
            Fit();
        }
        if(embedded && !resized && elapsed.ElapsedMilliseconds-attachMs>350) {
            host.Size=new Size(host.Width+80,host.Height+50);
            resized=true;
            Fit();
        }
        if(resized && File.Exists(guestOutput) &&
           elapsed.ElapsedMilliseconds-attachMs>1300){
            Finish("REPORT_READY");
        }
    }
    static void Finish(string state) {
        if(completed)return;
        completed=true;
        try{monitor.Stop();}catch{}
        RECT r1=new RECT(),r2=new RECT();
        bool ieRect=ieHwnd!=IntPtr.Zero&&GetClientRect(ieHwnd,out r1);
        bool guestRect=guestHwnd!=IntPtr.Zero&&GetClientRect(guestHwnd,out r2);
        int iw=ieRect?r1.Right-r1.Left:0;
        int ih=ieRect?r1.Bottom-r1.Top:0;
        int gw=guestRect?r2.Right-r2.Left:0;
        int gh=guestRect?r2.Bottom-r2.Top:0;
        string js=File.Exists(guestOutput)?File.ReadAllText(guestOutput):"";
        List<string> report=new List<string>();
        report.Add("State="+state);
        report.Add("LabOnly=true");
        report.Add("MessengerProcessTouched=false");
        report.Add("LegacyBrowserDocumentCompleted="+navigated);
        report.Add("InternetExplorerServerFound="+(ieHwnd!=IntPtr.Zero));
        report.Add("GuestAttachedToIEServer="+(embedded&&GetParent(guestHwnd)==ieHwnd));
        report.Add("ResizeAttempted="+resized);
        report.Add("OriginalIEServerWidth="+initialWidth);
        report.Add("OriginalIEServerHeight="+initialHeight);
        report.Add("IEServerWidthAfterResize="+iw);
        report.Add("IEServerHeightAfterResize="+ih);
        report.Add("GuestWidthAfterResize="+gw);
        report.Add("GuestHeightAfterResize="+gh);
        report.Add("ChildSizeMatches="+(ieRect&&guestRect&&iw==gw&&ih==gh));
        report.Add("WebView2ReportedOK="+js.Contains("State=OK"));
        report.Add("WebAssemblyInstantiated="+js.Contains("\\\"wasmInstantiate\\\":true"));
        report.Add("WebGLContextAvailable="+js.Contains("\\\"webgl\\\":true"));
        report.Add("PlaystorPasswordInputPresent="+js.Contains("\\\"passwordInputPresent\\\":true"));
        report.Add("PlaystorGameCanvasLikely="+js.Contains("\\\"gamePlayerLikely\\\":true"));
        report.Add("GameLaunched=false");
        report.Add("Milliseconds="+elapsed.ElapsedMilliseconds);
        try{File.WriteAllLines(output,report.ToArray());}catch{}
        try{host.Close();}catch{}
    }
    static void Cleanup() {
        try{monitor.Stop();monitor.Dispose();}catch{}
        if(guest==null)return;
        try {
            if(!guest.HasExited && guestHwnd!=IntPtr.Zero)
                PostMessage(guestHwnd,WM_CLOSE,IntPtr.Zero,IntPtr.Zero);
            if(!guest.HasExited&&!guest.WaitForExit(4500))guest.Kill();
        }catch{}
        try{guest.Dispose();}catch{}
    }
}
