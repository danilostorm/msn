@echo off
title Storm MSN - WLM 2009 Original
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar-StormMSN.ps1"
if errorlevel 1 (
 echo.
 echo A instalacao do Storm MSN encontrou um erro. Confira a mensagem acima.
 pause
)
