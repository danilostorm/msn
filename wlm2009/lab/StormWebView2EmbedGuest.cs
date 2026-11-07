// Storm MSN — LAB-ONLY WebView2 guest to test hosting in another Win32 process.
// No Messenger process, binary, UI resource or account is touched.
// Compiles as x86 .NET Framework with official Microsoft WebView2 SDK.
using System;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

internal static class StormWebView2EmbedGuest {
    const string Target = "https://msn.hoststorm.com.br/AppDirectory/Directory.aspx?from=wlm2009";
    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr GetParent(IntPtr hwnd);
    private static Form form;
    private static WebView2 view;
    private static Timer timer;
    private static bool wrote;
    private static string report;

    [STAThread]
    public static void Main(string[] args) {
        if (args.Length != 2 || args[0] != "--isolated-lab") return;
        report = Path.GetFullPath(args[1]);
        // Guard the report path to the same extracted laboratory directory.
        if (!report.StartsWith(AppDomain.CurrentDomain.BaseDirectory,
                StringComparison.OrdinalIgnoreCase)) return;
        Application.EnableVisualStyles();
        form = new Form();
        form.Name = "StormMSNWebView2LabGuest";
        form.Text = "Storm MSN LAB guest WebView2";
        form.FormBorderStyle = FormBorderStyle.None;
        form.StartPosition = FormStartPosition.Manual;
        form.Location = new Point(-30000, -30000);
        form.Size = new Size(660, 480);
        form.ShowInTaskbar = true;
        view = new WebView2();
        view.Dock = DockStyle.Fill;
        form.Controls.Add(view);
        timer = new Timer();
        timer.Interval = 28000;
        timer.Tick += delegate { Record("TIMEOUT", "unknown"); form.Close(); };
        timer.Start();
        form.Shown += async delegate {
            try {
                // Never touches user's Microsoft Edge/WLM profile.
                var profile = Path.Combine(AppDomain.CurrentDomain.BaseDirectory,
                                           "guest-profile");
                var env = await CoreWebView2Environment.CreateAsync(null, profile);
                await view.EnsureCoreWebView2Async(env);
                view.CoreWebView2.Settings.AreDevToolsEnabled = false;
                view.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
                view.CoreWebView2.NewWindowRequested += delegate(object sender, 
                        CoreWebView2NewWindowRequestedEventArgs e) {
                    e.Handled = true;
                };
                view.CoreWebView2.NavigationStarting += delegate(object sender, 
                        CoreWebView2NavigationStartingEventArgs e) {
                    if (!string.Equals(e.Uri, Target,
                            StringComparison.OrdinalIgnoreCase)) e.Cancel = true;
                };
                view.CoreWebView2.NavigationCompleted += async delegate(object sender, 
                        CoreWebView2NavigationCompletedEventArgs e) {
                    try {
                        if (!e.IsSuccess) {
                            Record("NAVIGATION_FAIL", e.WebErrorStatus.ToString());
                            return;
                        }
                        // Instantiate an original minimal WASM test module in
                        // the embedded renderer. No game assets or accounts used.
                        var js = await view.CoreWebView2.ExecuteScriptAsync(
                            "(function() { " +
                            "var x={wasm:typeof WebAssembly,fetch:typeof fetch," +
                            "playstor:!!document.body&&document.body.innerText.indexOf('PlayStor')>=0," +
                            "wasmInstantiate:false,webgl:false};" +
                            "try { var m=new WebAssembly.Module(new Uint8Array([0,97,115,109,1,0,0,0]));" +
                            "var i=new WebAssembly.Instance(m,{});x.wasmInstantiate=!!i; } catch(e) {}" +
                            "try { var c=document.createElement('canvas');" +
                            "x.webgl=!!(c.getContext('webgl2')||c.getContext('webgl'));" +
                            "} catch(e) {}" +
                            "return JSON.stringify(x); })()");

                        Record("OK", js);
                    } catch (Exception ex) {
                        Record("JS_" + ex.GetType().Name, "unknown");
                    }
                };
                view.CoreWebView2.Navigate(Target);
            } catch (Exception ex) {
                Record("INIT_" + ex.GetType().Name, "unknown");
            }
        };
        form.FormClosed += delegate {
            try { timer.Stop(); timer.Dispose(); } catch { }
            try { view.Dispose(); } catch { }
        };
        Application.Run(form);
    }

    private static void Record(string state, string js) {
        if (wrote) return;
        wrote = true;
        try {
            File.WriteAllLines(report, new string[] {
                "State=" + state,
                "JS=" + js,
                "WindowHandle=0x" + form.Handle.ToInt64().ToString("x"),
                "ParentAtCompletion=0x" + GetParent(form.Handle).ToInt64().ToString("x"),
                "Origin=" + Target,
                "LabOnly=true",
                "WLMProcessTouched=false",
                "GameLaunched=false",
            });
        } catch {}
    }
}
