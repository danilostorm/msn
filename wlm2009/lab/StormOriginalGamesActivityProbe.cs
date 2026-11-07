// Storm MSN 2009 original: sanitized live window + DirectUI activity watcher.
// Captures ONLY Win32 class names, counts, dimensions and UI Automation IDs.
// Does not read window titles, names, contact lists, emails, chat messages,
// credentials, screenshots, or browser profiles. NEVER modifies WLM/Edge.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows.Automation;

internal static class StormOriginalGamesActivityProbe {
    const string OriginalExe =
        @"C:\Program Files (x86)\Windows Live\Messenger\msnmsgr.exe";
    const string OriginalSha256 =
        "16660063313576d528e69bdbedb69e0c213b31cba0fae579f3e2482a00316f75";
    const string LabRoot =
        @"E:\StormMSN-Research\lab-native-2009\";
    const string ActivityId="convdraweractivityhost";

    [StructLayout(LayoutKind.Sequential)] struct RECT {
        public int Left,Top,Right,Bottom;
    }
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb,IntPtr data);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(
        IntPtr hwnd,EnumProc cb,IntPtr data);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(
        IntPtr hwnd,out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] static extern bool GetWindowRect(
        IntPtr hwnd,out RECT rect);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetClassName(
        IntPtr hwnd,StringBuilder text,int cap);
    delegate bool EnumProc(IntPtr hwnd,IntPtr data);

    struct Report {
        public int NativeRoots,VisibleRoots,ConversationCandidates,
            DirectUIWindows,IEWindows,ActivityIds,TrustedProcesses;
        public int CandidateWidth,CandidateHeight,ActivityWidth,ActivityHeight;
        public bool ActivityFound;
        public string CandidateClass;
        public string Signature() {
            return NativeRoots+"|"+VisibleRoots+"|"+ConversationCandidates+"|"+
              DirectUIWindows+"|"+IEWindows+"|"+ActivityIds+"|"+
              CandidateWidth+"x"+CandidateHeight+"|"+ActivityWidth+"x"+ActivityHeight+
              "|"+CandidateClass;
        }
    }

    static string ClassOf(IntPtr hwnd){
        StringBuilder s=new StringBuilder(160);
        GetClassName(hwnd,s,s.Capacity);
        return s.ToString();
    }
    static bool IsTrusted(Process p) {
        try {
            if(p.SessionId!=Process.GetCurrentProcess().SessionId)return false;
            if(!String.Equals(Path.GetFullPath(p.MainModule.FileName),OriginalExe,
                    StringComparison.OrdinalIgnoreCase))return false;
            using(SHA256 sha=SHA256.Create())
            using(FileStream fs=File.OpenRead(OriginalExe)) {
                var hash=sha.ComputeHash(fs);
                var sb=new StringBuilder(64);
                foreach(byte b in hash)sb.Append(b.ToString("x2"));
                return String.Equals(sb.ToString(),OriginalSha256,
                    StringComparison.OrdinalIgnoreCase);
            }
        }catch{return false;}
    }

    static Report Scan(){
        Report r=new Report();
        foreach(Process p in Process.GetProcessesByName("msnmsgr")){
            try {
                if(!IsTrusted(p))continue;
                r.TrustedProcesses++;
                uint owner=(uint)p.Id;
                EnumWindows(delegate(IntPtr hwnd,IntPtr ignored){
                    uint pid;GetWindowThreadProcessId(hwnd,out pid);
                    if(pid!=owner)return true;
                    string rootClass=ClassOf(hwnd);
                    bool isNativeRoot=rootClass=="MSBLWindowClass";
                    if(isNativeRoot)r.NativeRoots++;
                    if(!IsWindowVisible(hwnd))return true;
                    if(isNativeRoot)r.VisibleRoots++;
                    // Conversation windows can use classes other than
                    // MSBLWindowClass: inspect all visible top-level HWNDs
                    // owned by the verified ORIGINAL Messenger process.
                    RECT rect;
                    if(!GetWindowRect(hwnd,out rect))return true;
                    int w=rect.Right-rect.Left, h=rect.Bottom-rect.Top;
                    // Contact-list main window is around 310x700 and should
                    // never be classified as a conversation activity surface.
                    if(w>=375 && h>=300){
                        r.ConversationCandidates++;
                        if(w*h > r.CandidateWidth*r.CandidateHeight){
                            r.CandidateWidth=w;r.CandidateHeight=h;
                            r.CandidateClass=rootClass;
                        }
                        // Inspect only geometry/AutomationId. No UIA.Name or text.
                        try{
                            AutomationElement root=AutomationElement.FromHandle(hwnd);
                            if(root!=null){
                                AutomationElementCollection els=root.FindAll(
                                  TreeScope.Descendants,new PropertyCondition(
                                    AutomationElement.AutomationIdProperty,ActivityId));
                                r.ActivityIds+=els.Count;
                                for(int k=0;k<els.Count;k++){
                                    if(els[k].Current.IsOffscreen)continue;
                                    var bounds=els[k].Current.BoundingRectangle;
                                    if(bounds.Width>=200 && bounds.Height>=140 &&
                                       bounds.Width < w && bounds.Height < h){
                                        r.ActivityFound=true;
                                        r.ActivityWidth=(int)bounds.Width;
                                        r.ActivityHeight=(int)bounds.Height;
                                    }
                                }
                            }
                        }catch(COMException){}catch(ElementNotAvailableException){}
                         catch(InvalidOperationException){}
                    }
                    EnumChildWindows(hwnd,delegate(IntPtr child,IntPtr ignoredChild){
                        var cn=ClassOf(child);
                        if(cn=="DirectUIHWND")r.DirectUIWindows++;
                        if(cn=="Internet Explorer_Server")r.IEWindows++;
                        return true;
                    },IntPtr.Zero);
                    return true;
                },IntPtr.Zero);
            }finally{p.Dispose();}
        }
        return r;
    }

    static bool SelfTest(){
        bool a=OriginalSha256.Length==64;
        bool b=Path.GetFullPath(LabRoot).StartsWith(@"E:\StormMSN-Research\",
                StringComparison.OrdinalIgnoreCase);
        bool c=new Report{NativeRoots=1,VisibleRoots=1,
            ConversationCandidates=0,CandidateWidth=310,
            CandidateHeight=700}.Signature().Contains("310x700");
        Console.WriteLine("SELFTEST="+(a&&b&&c?"PASS":"FAIL"));
        return a&&b&&c;
    }

    [STAThread] static int Main(string[] args){
        if(args.Length==1&&args[0]=="--selftest")return SelfTest()?0:1;
        if(args.Length!=3||
           (args[0]!="--snapshot"&&args[0]!="--watch") ||
           args[1]!="--out"){
            Console.Error.WriteLine("Usage: --snapshot|--watch --out <lab_report.txt>");
            return 2;
        }
        string output=Path.GetFullPath(args[2]);
        if(!output.StartsWith(Path.GetFullPath(LabRoot),
            StringComparison.OrdinalIgnoreCase)){
            Console.Error.WriteLine("Report must remain in Nexus laboratory");
            return 2;
        }
        int seconds=args[0]=="--watch"?105:2;
        int intervalMs=args[0]=="--watch"?1500:500;
        var last="";
        var watch=Stopwatch.StartNew();
        var rows=new List<string>();
        rows.Add("Probe=Storm MSN 2009 original DirectUI activity");
        rows.Add("DataCollected=Win32 class counts and geometry, UIA AutomationId only");
        rows.Add("PrivateDataCollected=false");
        rows.Add("MessengerModified=false");
        rows.Add("EdgeAttached=false");
        rows.Add("RunningSession="+Process.GetCurrentProcess().SessionId);
        bool activityEverFound=false;
        int chatCandidateMax=0,ieMax=0,rootMax=0,changeCount=0;
        while(watch.Elapsed.TotalSeconds < seconds){
            Report r=Scan();
            activityEverFound |= r.ActivityFound;
            chatCandidateMax=Math.Max(chatCandidateMax,r.ConversationCandidates);
            ieMax=Math.Max(ieMax,r.IEWindows);
            rootMax=Math.Max(rootMax,r.VisibleRoots);
            var signature=r.Signature();
            if(last!=signature){
                changeCount++;
                string row="T+"+watch.ElapsedMilliseconds+"ms"+
                    " trusted="+r.TrustedProcesses+
                    " roots="+r.NativeRoots+
                    " visible="+r.VisibleRoots+
                    " conversationCandidates="+r.ConversationCandidates+
                    " DirectUIHWND="+r.DirectUIWindows+
                    " IE_Server="+r.IEWindows+
                    " activityId="+r.ActivityIds+
                    " conversationSize="+r.CandidateWidth+"x"+r.CandidateHeight+
                    " activitySize="+r.ActivityWidth+"x"+r.ActivityHeight+
                    " candidateClass="+(r.CandidateClass??"none");
                rows.Add(row);
                Console.WriteLine(row);
                last=signature;
            }
            Thread.Sleep(intervalMs);
        }
        rows.Add("SUMMARY_ActivityFound="+activityEverFound);
        rows.Add("SUMMARY_ConversationWindowCandidates="+chatCandidateMax);
        rows.Add("SUMMARY_MaxIE_Server="+ieMax);
        rows.Add("SUMMARY_MaxVisibleNativeRoots="+rootMax);
        rows.Add("SUMMARY_WindowStateChanges="+changeCount);
        rows.Add("CONCLUSION="+(activityEverFound ?
            "DIRECTUI_ACTIVITY_ID_VISIBLE":
            chatCandidateMax>0?
            "CONVERSATION_SEEN_NO_ACTIVITY_ID":
            "NO_CONVERSATION_DETECTED"));
        string dir=Path.GetDirectoryName(output);
        if(!Directory.Exists(dir))Directory.CreateDirectory(dir);
        File.WriteAllLines(output,rows.ToArray(),new UTF8Encoding(false));
        Console.WriteLine("REPORT="+output);
        return 0;
    }
}
