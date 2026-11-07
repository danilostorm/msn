// Storm MSN WLM2009 — Edge-only, read-only game-surface eligibility gate.
// This utility never starts a browser, never injects code, never uses IE/Trident.
// Its purpose is to refuse to cover the Messenger's original UI until a real
// DirectUI game container is demonstrably available and geometrically safe.
// Build x86 with .NET Framework 4.8 + UIAutomationClient/UIAutomationTypes.
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Runtime.InteropServices;
using System.Windows.Automation;

internal static class StormEdgeSurfaceGuard {
    const string OriginalExePath = @"C:\Program Files (x86)\Windows Live\Messenger\msnmsgr.exe";
    const string OriginalExeSha256 = "16660063313576d528e69bdbedb69e0c213b31cba0fae579f3e2482a00316f75";
    const string NativeWindowClass = "MSBLWindowClass";
    const string ActivityId = "convdraweractivityhost";

    delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc fn, IntPtr data);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    static extern int GetClassName(IntPtr hwnd, StringBuilder sb, int cap);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out WinRect r);
    [StructLayout(LayoutKind.Sequential)] struct WinRect {
        public int Left, Top, Right, Bottom;
    }
    struct Box {
        public double X, Y, W, H;
        public Box(double x, double y, double w, double h) {
            X=x;Y=y;W=w;H=h;
        }
    }
    static string outputFile;
    static readonly List<string> results = new List<string>();
    static int candidateCount;
    static bool accepted;

    // Validate the activity area even if a title/ID has been spoofed by
    // another UI element: never allow root/full-window overlays.
    static bool SafeGeometry(Box root, Box activity) {
        if (root.W < 500 || root.H < 380) return false; // contact list/login
        if (activity.W < 240 || activity.H < 170) return false;
        if (activity.W > 1500 || activity.H > 1050) return false;
        if (activity.W * activity.H > root.W * root.H * 0.70) return false;
        if (activity.X < root.X+8 || activity.Y < root.Y+8) return false;
        if (activity.X+activity.W > root.X+root.W-8) return false;
        if (activity.Y+activity.H > root.Y+root.H-8) return false;
        if (Double.IsNaN(activity.X) || Double.IsNaN(activity.Y) ||
            Double.IsInfinity(activity.W) || Double.IsInfinity(activity.H)) return false;
        return true;
    }

    static bool SelfTest() {
        Box root = new Box(80,60,920,720);
        Box activity = new Box(520,140,370,410);
        var cases = new KeyValuePair<string,bool>[] {
            new KeyValuePair<string,bool>("valid_game_slot",SafeGeometry(root,activity)),
            new KeyValuePair<string,bool>("reject_full_window",!SafeGeometry(root,root)),
            new KeyValuePair<string,bool>("reject_contacts",!SafeGeometry(
                new Box(150,210,310,700),new Box(155,240,285,600))),
            new KeyValuePair<string,bool>("reject_tiny_slot",!SafeGeometry(
                root,new Box(530,240,80,50))),
            new KeyValuePair<string,bool>("reject_outside",!SafeGeometry(
                root,new Box(925,140,350,300))),
            new KeyValuePair<string,bool>("reject_huge_area",!SafeGeometry(
                root,new Box(98,77,885,685))),
            new KeyValuePair<string,bool>("reject_root_edge",!SafeGeometry(
                root,new Box(80,80,320,250))),
            new KeyValuePair<string,bool>("reject_non_finite",!SafeGeometry(
                root,new Box(340,100,Double.NaN,300))),
        };
        bool ok=true;
        foreach(var c in cases) {
            Console.WriteLine(c.Key+"="+(c.Value?"PASS":"FAIL"));
            if(!c.Value)ok=false;
        }
        Console.WriteLine("SELFTEST_RESULT="+(ok?"PASS":"FAIL"));
        return ok;
    }

    static string Hash(string file) {
        using(SHA256 sha=SHA256.Create())
        using(FileStream stream=File.OpenRead(file)) {
            byte[] digest=sha.ComputeHash(stream);
            StringBuilder sb=new StringBuilder(64);
            foreach(byte b in digest)sb.Append(b.ToString("x2"));
            return sb.ToString();
        }
    }

    static bool RealMessengerProcess(Process p) {
        if (p.ProcessName!="msnmsgr" ||
            p.SessionId!=Process.GetCurrentProcess().SessionId) return false;
        try {
            string path=p.MainModule.FileName;
            if(!string.Equals(Path.GetFullPath(path),OriginalExePath,
                StringComparison.OrdinalIgnoreCase))return false;
            return string.Equals(Hash(path),OriginalExeSha256,
                StringComparison.OrdinalIgnoreCase);
        }catch{return false;}
    }
    static List<IntPtr> NativeRootWindows(uint pid) {
        var roots=new List<IntPtr>();
        EnumWindows(delegate(IntPtr hwnd,IntPtr data){
            uint owner;GetWindowThreadProcessId(hwnd,out owner);
            if(owner!=pid || !IsWindowVisible(hwnd))return true;
            StringBuilder cn=new StringBuilder(128);
            GetClassName(hwnd,cn,cn.Capacity);
            if(cn.ToString()==NativeWindowClass) roots.Add(hwnd);
            return true;
        },IntPtr.Zero);
        return roots;
    }
    static Box? RectFor(IntPtr hwnd){
        WinRect r;
        if(!GetWindowRect(hwnd,out r))return null;
        return new Box(r.Left,r.Top,r.Right-r.Left,r.Bottom-r.Top);
    }
    static bool InspectWindow(IntPtr hwnd, uint pid) {
        Box? rootRect=RectFor(hwnd);
        if(!rootRect.HasValue) return false;
        if(rootRect.Value.W<500 || rootRect.Value.H<380) {
            results.Add("root_rejected=contacts_or_small_window");return false;
        }
        try {
            AutomationElement root=AutomationElement.FromHandle(hwnd);
            if(root==null){results.Add("uia_root_absent");return false;}
            AutomationElementCollection found=root.FindAll(
                TreeScope.Descendants,
                new PropertyCondition(AutomationElement.AutomationIdProperty,ActivityId));
            results.Add("uia_matching_activity_ids="+found.Count);
            // Ambiguous overlapping surfaces are unsafe.
            if(found.Count!=1) return false;
            var el=found[0];
            if(el.Current.ProcessId!=(int)pid) {
                results.Add("reject_wrong_process");return false;
            }
            if(el.Current.IsOffscreen){
                results.Add("reject_activity_offscreen");return false;
            }
            var r=el.Current.BoundingRectangle;
            Box slot=new Box(r.Left,r.Top,r.Width,r.Height);
            if(!SafeGeometry(rootRect.Value,slot)) {
                results.Add("reject_activity_geometry");return false;
            }
            candidateCount++;
            results.Add("verified_activity_width="+Math.Round(slot.W));
            results.Add("verified_activity_height="+Math.Round(slot.H));
            // This read-only implementation intentionally never attaches a
            // window: separate acceptance into an explicit future implementation.
            results.Add("validated_game_surface=true");
            return true;
        }catch(COMException){
            results.Add("uia_com_unavailable");return false;
        }catch(ElementNotAvailableException){
            results.Add("uia_element_lost");return false;
        }catch(InvalidOperationException){
            results.Add("uia_invalid_operation");return false;
        }
    }

    [STAThread]
    static int Main(string[] args) {
        if(args.Length==1 && args[0]=="--selftest")
            return SelfTest()?0:1;
        if(args.Length!=2 || args[0]!="--scan") {
            Console.Error.WriteLine("Usage: --scan <output.txt> or --selftest");
            return 2;
        }
        outputFile=Path.GetFullPath(args[1]);
        var allowedRoot=Path.GetFullPath(
            @"E:\StormMSN-Research\lab-native-2009\") ;
        if(!outputFile.StartsWith(allowedRoot,StringComparison.OrdinalIgnoreCase)){
            Console.Error.WriteLine("Reports must remain inside isolated lab.");
            return 2;
        }
        results.Add("Engine=EdgeWebView2_only");
        results.Add("Inspector=Win32_UIAutomation_read_only");
        results.Add("ProcessSession="+Process.GetCurrentProcess().SessionId);
        int eligible=0;
        int roots=0, trusted=0;
        foreach(Process p in Process.GetProcessesByName("msnmsgr")){
            try {
                if(!RealMessengerProcess(p))continue;
                trusted++;
                foreach(IntPtr hwnd in NativeRootWindows((uint)p.Id)){
                    roots++;
                    if(InspectWindow(hwnd,(uint)p.Id))eligible++;
                }
            }finally{p.Dispose();}
        }
        results.Add("OriginalWLMProcessVerified="+(trusted>0));
        results.Add("NativeRootWindows="+roots);
        results.Add("VerifiedActivitySurfaces="+eligible);
        results.Add("AttachAllowed=false");
        results.Add("Reason=This read-only detector does not modify WLM or attach Edge.");
        results.Add("CookiesCredentialsMessagesRead=false");
        results.Add("Result="+(eligible==1?"ACTIVITY_GEOMETRY_VERIFIED":"NO_SAFE_ACTIVITY_SURFACE"));
        File.WriteAllLines(outputFile,results.ToArray());
        foreach(string line in results)Console.WriteLine(line);
        return 0;
    }
}
