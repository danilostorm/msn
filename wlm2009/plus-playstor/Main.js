// Storm MSN PlayStor / Messenger Plus! 5.02 / JScript 5.x
// Preserves the ORIGINAL Windows Live Messenger 2009 interface.
// Never reads/sends chat messages, contact lists, email or credentials.
// Launches ONLY the local Edge WebView2 companion. No Microsoft binary patch.

var STORM_PLAYSTOR_EDGE =
  "E:\\StormMSN-Research\\lab-native-2009\\webview2-poc\\build\\StormEdgePlaystorLauncher.exe";

function OnGetScriptMenu(nLocation) {
  return '<ScriptMenu>' +
    '<MenuEntry Id="StormPlayStorCatalog">Jogos PlayStor (Edge)</MenuEntry>' +
    '</ScriptMenu>';
}

function OnEvent_MenuClicked(sMenuId, nLocation, iOriginWnd) {
  if (sMenuId !== "StormPlayStorCatalog") return;
  try {
    var fs = new ActiveXObject("Scripting.FileSystemObject");
    if (!fs.FileExists(STORM_PLAYSTOR_EDGE)) {
      MsgPlus.DisplayToast("Storm MSN", "O componente Edge WebView2 nao esta instalado neste PC.");
      return;
    }
    var shell = new ActiveXObject("WScript.Shell");
    shell.Run('"' + STORM_PLAYSTOR_EDGE + '" --catalog', 1, false);
  } catch (e) {
    MsgPlus.DisplayToast("Storm MSN", "Falha ao abrir o catalogo PlayStor.");
  }
}
