@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Abrir-StormMSN-Original.ps1" %*
if errorlevel 1 (
  echo.
  echo Falha ao abrir o Windows Live Messenger ORIGINAL.
  echo Confira a mensagem acima. Nao execute este iniciador como administrador.
  pause
)
