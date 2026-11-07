@echo off
setlocal
chcp 65001 >nul
title Storm MSN 2009 - Teste original de Jogos
set "ROOT=%~dp0"
set "PROBE=%ROOT%webview2-poc\build\StormOriginalGamesActivityProbe.exe"
set "REPORT=%ROOT%webview2-poc\build\ActivityProbe-Teste-Manual.txt"
if not exist "%PROBE%" (
  echo ERRO: nao encontrei o verificador no laboratorio.
  echo Arquivo esperado: %PROBE%
  pause
  exit /b 1
)
echo =====================================================
echo      STORM MSN 2009 - TESTE ORIGINAL DE JOGOS
echo =====================================================
echo.
echo Este teste nao captura conversas, contatos ou senhas.
echo Nao modifica o cliente Microsoft e nao inicia jogos.
echo.
echo Assim que apertar qualquer tecla:
echo  1. Abra a janela ORIGINAL do Messenger 2009.
echo  2. Abra uma conversa com uma conta de TESTE.
echo  3. Clique no botao original Jogos, se estiver disponivel.
echo  4. Aguarde o catalogo aparecer e feche apenas depois
echo     que o diagnostico terminar.
echo.
echo O programa observa a tela por ate 105 segundos.
echo Ele registra APENAS a geometria das janelas.
echo.
pause
"%PROBE%" --watch --out "%REPORT%"
set "CODE=%ERRORLEVEL%"
echo.
echo Relatorio salvo em: %REPORT%
echo Codigo: %CODE%
echo Nao precisa enviar capturas de conversas nem senhas.
echo Informe apenas se o botao Jogos abriu o catalogo
echo e se apareceu algum erro.
echo.
pause
exit /b %CODE%
