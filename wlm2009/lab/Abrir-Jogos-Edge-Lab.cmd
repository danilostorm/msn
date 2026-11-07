@echo off
setlocal
rem Storm MSN 2009: Edge WebView2 games laboratory launcher.
rem Does not replace msnmsgr.exe, alter WLM resources, or change default browser.
set "EDGE_LAB=%~dp0webview2-poc\build"
if not exist "%EDGE_LAB%\StormEdgePlaystorLauncher.exe" (
  echo Componente Edge WebView2 do laboratorio nao encontrado.
  echo Local esperado: %EDGE_LAB%\StormEdgePlaystorLauncher.exe
  exit /b 1
)
start "" "%EDGE_LAB%\StormEdgePlaystorLauncher.exe" --catalog
exit /b 0
