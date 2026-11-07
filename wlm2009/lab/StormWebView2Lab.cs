// Storm MSN laboratory ONLY: modern WebView2 engine capability probe.
// This is NOT a replacement Messenger client and does NOT attach to WLM.
// The original Messenger files and UI remain untouched.
// Requires the locally installed Microsoft Edge WebView2 Runtime and
// Microsoft.Web.WebView2 NuGet SDK (compile in separate lab folder).
using System;
using System.IO;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Windows.Forms;
using System.Drawing;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

public static class StormWebView2Lab {
    static Form window;
    static WebView2 browser;
    static Timer timeout;
    static bool done;
    static string output;
    static Stopwatch elapsed;
    const string GamesUrl =
        "https://msn.hoststorm.com.br/AppDirectory/Directory.aspx?from=wlm2009";
    [STAThread]
    public static void Main(string[] args) {
        output = args.Length > 0 ? args[0] : Path.Combine(
            AppDomain.CurrentDomain.BaseDirectory, "WebView2-Games-Result.txt");
        elapsed = Stopwatch.StartNew();
        try {
            Application.EnableVisualStyles();
            window = new Form();
            window.Width = 900;
            window.Height = 750;
            window.StartPosition = FormStartPosition.Manual;
            window.Location = new Point(-30000, -30000);
            window.ShowInTaskbar = false;
            window.Opacity = 0;
            window.Text = "Storm MSN isolated browser capability test";

            browser = new WebView2();
            browser.Dock = DockStyle.Fill;
            window.Controls.Add(browser);

            timeout = new Timer();
            timeout.Interval = 20000;
            timeout.Tick += (sender, e) => Finish("TIMEOUT", "unavailable");
            timeout.Start();

            window.Shown += async (sender, e) => {
                try {
                    // Isolated profile: never reads the user's Edge/WLM cookies.
                    string userData = Path.Combine(
                        AppDomain.CurrentDomain.BaseDirectory, "isolated-profile");
                    var env = await CoreWebView2Environment.CreateAsync(
                        null, userData);
                    await browser.EnsureCoreWebView2Async(env);

                    browser.CoreWebView2.Settings.AreDevToolsEnabled = false;
                    browser.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
                    browser.CoreWebView2.NewWindowRequested +=
                      (s, ev) => { ev.Handled = true; };
                    browser.CoreWebView2.NavigationStarting +=
                      (s, ev) => {
                          if (!ev.Uri.Equals(GamesUrl,
                              StringComparison.OrdinalIgnoreCase)) {
                              ev.Cancel = true;
                          }
                      };
                    browser.CoreWebView2.NavigationCompleted +=
                        async (s, ev) => {
                            try {
                                if (!ev.IsSuccess) {
                                    Finish("NAVIGATION_FAILED", ev.WebErrorStatus.ToString());
                                    return;
                                }
                                string features = await browser.CoreWebView2.ExecuteScriptAsync(
                                    "JSON.stringify({WebAssembly:typeof WebAssembly,fetch:typeof fetch,WebSocket:typeof WebSocket,canvas:typeof document.createElement('canvas').getContext,PlayStorPresent:!!document.body&&document.body.innerText.indexOf('PlayStor')>=0})");
                                Finish("OK", features);
                            } catch (Exception ex) {
                                Finish("JS_" + ex.GetType().Name, "unknown");
                            }
                        };
                    browser.CoreWebView2.Navigate(GamesUrl);
                } catch (Exception ex) {
                    Finish("INIT_" + ex.GetType().Name, "unknown");
                }
            };
            Application.Run(window);
        } catch (Exception ex) {
            WriteResult("FAILED_" + ex.GetType().Name, "unknown");
        }
    }

    static void Finish(string status, string features) {
        if (done) return;
        done = true;
        try { if (timeout != null) timeout.Stop(); } catch { }
        WriteResult(status, features);
        try { if (window != null) window.Close(); } catch { }
    }

    static void WriteResult(string status, string features) {
        try {
            string[] lines = {
                "Test=Standalone WebView2 GamesBrowserURL capability",
                "Status=" + status,
                "Features=" + features,
                "ElapsedMilliseconds=" + elapsed.ElapsedMilliseconds,
                "MSNProcessTouched=false",
                "ClientResourcesModified=false",
                "GamesExecuted=false",
                "BrowserProfile=isolated",
            };
            File.WriteAllLines(output, lines);
        } catch { }
    }
}
