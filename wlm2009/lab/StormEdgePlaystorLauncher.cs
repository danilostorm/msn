// Storm MSN PlayStor — Edge WebView2 companion, NOT a replacement Messenger.
// This is a standalone game-rendering laboratory component. Windows Live
// Messenger 2009 (msnmsgr.exe/msgsres.dll/DirectUI) is never changed.
// Compatible with x86 .NET Framework 4.8 + Microsoft.Web.WebView2 SDK.
//
// CLI: --selftest
//      --play 673
//      --uri stormmsn-game://play/673
//      --catalog
//      --smoke --play 673 --report <file inside laboratory>
using System;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Text;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

internal static class StormEdgePlaystorLauncher {
    const string PlayStorHost="playstor.hoststorm.cloud";
    const string PlayStorOrigin="https://playstor.hoststorm.cloud";
    const string GamesHome="https://msn.hoststorm.com.br/AppDirectory/Directory.aspx?from=wlm2009";
    static readonly string LabRoot=@"E:\StormMSN-Research\lab-native-2009\";
    static Form win;
    static WebView2 web;
    static Timer stop;
    static string reportPath;
    static bool smoke, completed, navigationOk, followFirstGame, catalogClicked, targetNavigated;
    static string entryUrl, status="NOT_STARTED", runtimeInfo="unknown";
    static Stopwatch watch;

    static bool TryGameId(string value,out int id){
        id=0;
        if(String.IsNullOrWhiteSpace(value)||value.Length>9)return false;
        foreach(char c in value)if(c<'0'||c>'9')return false;
        return Int32.TryParse(value,NumberStyles.None,
                    CultureInfo.InvariantCulture,out id)&&id>0;
    }
    static bool TryDeepLink(string link,out int id) {
        id=0;
        Uri uri;
        if(!Uri.TryCreate(link,UriKind.Absolute,out uri))return false;
        if(!uri.Scheme.Equals("stormmsn-game",StringComparison.OrdinalIgnoreCase) ||
           !uri.Host.Equals("play",StringComparison.OrdinalIgnoreCase) ||
           uri.Port!=-1 || !String.IsNullOrEmpty(uri.UserInfo) ||
           !String.IsNullOrEmpty(uri.Query) || !String.IsNullOrEmpty(uri.Fragment))
            return false;
        string path=uri.AbsolutePath.TrimStart('/');
        if(path.Contains("/")||path.Contains("%"))return false;
        return TryGameId(path,out id);
    }
    static bool InsideLab(string path){
        string full=Path.GetFullPath(path);
        return full.StartsWith(Path.GetFullPath(LabRoot),
                StringComparison.OrdinalIgnoreCase);
    }
    static bool SafeMainNavigation(string requested,bool gameMode){
        Uri uri;
        if(!Uri.TryCreate(requested,UriKind.Absolute,out uri) ||
           uri.Scheme!=Uri.UriSchemeHttps || uri.Port!=443 ||
           !String.IsNullOrEmpty(uri.UserInfo))return false;
        if(uri.Host.Equals(PlayStorHost,StringComparison.OrdinalIgnoreCase))
            return true;
        // Public directory is permitted ONLY in catalog mode.
        return !gameMode && uri.Host.Equals("msn.hoststorm.com.br",
             StringComparison.OrdinalIgnoreCase) &&
             uri.AbsolutePath.Equals("/AppDirectory/Directory.aspx",
             StringComparison.OrdinalIgnoreCase);
    }
    static bool SelfTest() {
        string[] good={"1","673","999999999"};
        foreach(string id in good){
            int parsed;
            if(!TryGameId(id,out parsed))return Fail("good_id_"+id);
            if(!TryDeepLink("stormmsn-game://play/"+id,out parsed))
                return Fail("good_deeplink_"+id);
        }
        string[] bad={
            "0","-1","1&x=2","../673","1000000000","673/1","abc","",
            "https://playstor.hoststorm.cloud/?play=673",
            "stormmsn-game://other/673",
            "stormmsn-game://play/673?token=secret",
            "stormmsn-game://play/673#abc",
            "stormmsn-game://play/%36%37%33",
            "stormmsn-game://play/673/extra",
            "stormmsn-game://user@play/673"
        };
        foreach(string value in bad){
            int parsed;
            if(TryDeepLink(value,out parsed))
                return Fail("bad_deeplink_accepted_"+value);
        }
        foreach(string url in new[]{
            "http://playstor.hoststorm.cloud/?play=673",
            "https://other.example/?play=673",
            "file:///C:/Windows/win.ini",
            "https://playstor.hoststorm.cloud.evil.example/?play=673",
            "https://msn.hoststorm.com.br/AppDirectory/Directory.aspx"
        })if(SafeMainNavigation(url,true))
            return Fail("foreign_navigation_"+url);
        if(!SafeMainNavigation(PlayStorOrigin+"/?play=673",true))
            return Fail("playstor_blocked");
        if(!SafeMainNavigation(GamesHome,false))
            return Fail("catalog_blocked");
        Console.WriteLine("SELFTEST=PASS");
        Console.WriteLine("VALIDATED=direct_player_id,deeplink,origin,protocol");
        return true;
    }
    static bool Fail(string reason){Console.WriteLine("SELFTEST=FAIL "+reason);return false;}
    static bool ParseArgs(string[] args,out string url){
        url=null;
        bool catalog=false;
        int id=0;
        string deep=null;
        for(int i=0;i<args.Length;i++){
            switch(args[i]){
                case "--catalog": catalog=true;break;
                case "--play":
                    if(i+1>=args.Length||!TryGameId(args[++i],out id))return false;
                    break;
                case "--uri":
                    if(i+1>=args.Length) return false;
                    deep=args[++i];break;
                case "--smoke":smoke=true;break;
                case "--follow-first-game":followFirstGame=true;break;
                case "--report":
                    if(i+1>=args.Length) return false;
                    reportPath=Path.GetFullPath(args[++i]);
                    if(!InsideLab(reportPath))return false;
                    break;
                default:return false;
            }
        }
        if(catalog && (id>0||deep!=null))return false;
        if(deep!=null){
            if(id>0||!TryDeepLink(deep,out id))return false;
        }
        if(catalog)url=GamesHome;
        else if(id>0)url=PlayStorOrigin+"/?play="+id;
        if(url==null || (followFirstGame && (!smoke || !catalog)) ||
           (smoke && reportPath==null) ||
           (!smoke && reportPath!=null))return false;
        return true;
    }
    [STAThread]
    static int Main(string[] args){
        if(args.Length==1 && args[0]=="--selftest")return SelfTest()?0:1;
        if(!ParseArgs(args,out entryUrl)){
            Console.Error.WriteLine("Usage: --play <numeric-id> | --uri stormmsn-game://play/<id> | --catalog [--smoke --report <lab-file>]");
            return 2;
        }
        watch=Stopwatch.StartNew();
        Application.EnableVisualStyles();
        win=new Form();
        win.Text="PlayStor · Edge WebView2 (Storm MSN lab)";
        win.Width=1000; win.Height=740;
        win.MinimumSize=new Size(500,390);
        win.StartPosition=FormStartPosition.CenterScreen;
        win.ShowInTaskbar=!smoke;
        if(smoke){
            win.StartPosition=FormStartPosition.Manual;
            win.Location=new Point(-30000,-30000);
            win.Opacity=0;
        }
        web=new WebView2();
        web.Dock=DockStyle.Fill;
        win.Controls.Add(web);
        stop=new Timer();
        stop.Interval=14500;
        if(smoke){
            stop.Tick+=(s,e)=>Finish("TIMEOUT");
            stop.Start();
        }
        win.Shown+=async(s,e)=>{
            try{
                string dataRoot=Path.Combine(LabRoot,
                                     "edge-player-profile");
                Directory.CreateDirectory(dataRoot);
                var env=await CoreWebView2Environment.CreateAsync(null,dataRoot);
                await web.EnsureCoreWebView2Async(env);
                web.CoreWebView2.Settings.AreDevToolsEnabled=false;
                web.CoreWebView2.Settings.AreDefaultContextMenusEnabled=true;
                bool playMode=entryUrl.StartsWith(PlayStorOrigin,
                                     StringComparison.OrdinalIgnoreCase);
                web.CoreWebView2.NavigationStarting+=(sender,ev)=>{
                    if(!SafeMainNavigation(ev.Uri,playMode))ev.Cancel=true;
                };
                web.CoreWebView2.NewWindowRequested+=(sender,ev)=>{
                    ev.Handled=true;
                    // No arbitrary browser windows or external protocols.
                    if(SafeMainNavigation(ev.Uri,playMode)){
                        web.CoreWebView2.Navigate(ev.Uri);
                    }
                };
                web.CoreWebView2.NavigationCompleted+=async(sender,ev)=>{
                    if(completed)return;
                    navigationOk=ev.IsSuccess;
                    status=ev.IsSuccess?"PAGE_LOADED":"NAVIGATION_"+ev.WebErrorStatus;
                    if(smoke && followFirstGame && ev.IsSuccess &&
                       web.Source!=null &&
                       web.Source.Host.Equals("msn.hoststorm.com.br",
                            StringComparison.OrdinalIgnoreCase) && !catalogClicked) {
                        catalogClicked=true;
                        // Exercise the real public catalog's first game link
                        // without opening any browser other than WebView2.
                        string clicked=await web.CoreWebView2.ExecuteScriptAsync(
                           "(function(){var a=document.querySelector('a.play');" +
                           "if(!a||!/^https:\\\/\\\/playstor\\.hoststorm\\.cloud\\\/\\?play=[0-9]+$/i.test(a.href))return false;" +
                           "a.click();return true;})()");
                        if(clicked!="true")Finish("DIRECT_PLAYER_LINK_MISSING");
                        return;
                    }
                    if(smoke && followFirstGame && ev.IsSuccess &&
                       web.Source!=null &&
                       web.Source.Host.Equals("msn.hoststorm.com.br",
                            StringComparison.OrdinalIgnoreCase))return;
                    if(smoke){
                        try{
                            await System.Threading.Tasks.Task.Delay(2300);
                            runtimeInfo=await web.CoreWebView2.ExecuteScriptAsync(
                              "(function(){return JSON.stringify({"+
                              "webAssembly:typeof WebAssembly,playRequested:"+
                              "new URLSearchParams(location.search).has('play'),"+
                              "loginVisible:(function(){var x=document.getElementById('playstor-login');"+
                              "return !!x&&!x.classList.contains('hidden');})(),"+
                              "shellVisible:(function(){var x=document.getElementById('shell');"+
                              "return !!x&&!x.classList.contains('hidden');})()});})()");
                        }catch(Exception ex){runtimeInfo="JS_"+ex.GetType().Name;}
                        Finish(status);
                    }
                };
                web.CoreWebView2.Navigate(entryUrl);
            }catch(Exception ex){Finish("INIT_"+ex.GetType().Name);}
        };
        win.FormClosed+=(s,e)=>{
            try{stop.Stop();stop.Dispose();}catch{}
            try{web.Dispose();}catch{}
        };
        Application.Run(win);
        return status=="PAGE_LOADED"||!smoke?0:1;
    }
    static void Finish(string state){
        if(completed)return;completed=true;
        status=state;
        if(smoke&&InsideLab(reportPath)){
            // No credentials, cookies, contacts, page text or tokens logged.
            File.WriteAllLines(reportPath,new[]{
                "Status="+state,
                "Engine=EdgeWebView2",
                "LabOnly=true",
                "WLMModified=false",
                "URLHost="+new Uri(entryUrl).Host,
                "FinalHost="+(web!=null && web.Source!=null ? web.Source.Host : "none"),
                "FollowFirstGame="+followFirstGame,
                "CatalogClickAttempted="+catalogClicked,
                "NavigationSuccess="+navigationOk,
                "FeatureStatus="+runtimeInfo,
                "ElapsedMilliseconds="+watch.ElapsedMilliseconds,
                "CredentialsRead=false",
                "GameLaunched=false"
            });
        }
        try{win.Close();}catch{}
    }
}
