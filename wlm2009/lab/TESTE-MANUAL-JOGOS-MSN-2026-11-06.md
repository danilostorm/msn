# Storm MSN 2009 — teste manual seguro da janela original de Jogos

**Status:** ferramentas preparadas no Nexus e testes automáticos aprovados.
**Objetivo:** detectar a janela real de conversa do Messenger 2009 e a
área original de atividades/jogos, para integrar Edge WebView2 sem
sobrepor ou redesenhar a interface Microsoft.

## Arquivos instalados no Nexus

- Iniciador do teste:
  `E:\StormMSN-Research\lab-native-2009\Testar-Jogos-MSN-Original.cmd`
- Detector x86:
  `E:\StormMSN-Research\lab-native-2009\webview2-poc\build\StormOriginalGamesActivityProbe.exe`
- Resultado:
  `E:\StormMSN-Research\lab-native-2009\webview2-poc\build\ActivityProbe-Teste-Manual.txt`
- Iniciador Edge para os jogos:
  `E:\StormMSN-Research\lab-native-2009\Abrir-Jogos-Edge-Lab.cmd`
- Catálogo com modo de teste:
  `https://msn.hoststorm.com.br/AppDirectory/Directory.aspx?edge=1`

## O teste que precisamos de uma pessoa no PC

1. Na área de trabalho do **Nexus**, abra o arquivo
   `Testar-Jogos-MSN-Original.cmd`.
2. Pressione uma tecla na janela de diagnóstico. O detector observará
   a sessão gráfica por até **105 segundos**.
3. Nesse período, abra a janela do **Messenger 2009 original**, entre
   em uma conversa com uma **conta de teste** e clique em **Jogos**,
   sem precisar enviar mensagens.
4. Se o catálogo abrir, clique em
   **Ativar modo experimental Edge WebView2 (Nexus)** e então
   **Jogar com Edge WebView2**. Se o Windows mostrar uma solicitação
   de abrir um aplicativo, verifique se o destino é o nosso
   `StormEdgePlaystorLauncher.exe` no laboratório; não prossiga se
   mostrar outra aplicação. Não precisa efetuar login no PlayStor
   nesta etapa.
5. Espere o diagnóstico terminar. Responda no ChatGPT apenas
   **"teste concluído"** e diga se o menu Jogos abriu, se apareceu
   alguma confirmação e se abriu a janela WebView2.

A ferramenta **não coleta screenshots, nomes, contatos, conversas,
senhas, tokens, emails ou conteúdo das páginas**. Ela registra
somente nome de classe Win32, medidas, contadores e identificador
UI Automation `convdraweractivityhost`. O resultado ficará apenas
no Nexus e poderá ser lido depois por HOSTSTORM SSH. Não é necessário
enviar arquivo nem captura de conversas.

## Observações técnicas

- O detector reconhece o `msnmsgr.exe` original por caminho,
  sessão gráfica e SHA-256 do executável preservado.
- O teste atualiza a detecção para janelas de conversa de
  **qualquer classe Win32** pertencente ao processo original, não
  apenas `MSBLWindowClass` da lista de contatos.
- A sessão gráfica 1 foi verificada, com `msnmsgr.exe` legítimo
  presente, mas **sem conversa visível** antes do teste manual.
- O detector funciona por leitura passiva e **não injeta código**
  nem anexa o Edge ao Messenger real.
- Quando detectar um HWND adequado, o próximo passo será medir
  as bordas do painel de atividades e testar o encaixe em uma
  **cópia de laboratório**, sem alterar o programa instalado.
- Caso o botão Jogos esteja ausente ou não funcione, esse resultado
  também é válido: indica que precisamos analisar o comando nativo
  `GamesLobby` antes da incorporação.

## Pontos já validados automaticamente

- Link do catálogo passa a `?play=<id>` para iniciar player
  depois de autenticação.
- No modo padrão do catálogo, não existe `stormmsn-game://`.
- No modo `edge=1`, aparece um link
  `stormmsn-game://play/<id>`, reversível pelo
  botão de desativação.
- Protocolo `stormmsn-game://` instalado **somente para o usuário**
  de laboratório do Nexus, sem alterar navegador padrão.
- O Windows iniciou corretamente um processo Edge WebView2 ao
  receber esse link.
- O login do PlayStor é preservado; nenhum jogo foi iniciado
  sem autenticação.
- A suíte Python/PowerShell/Node no GitHub Actions passou.
- O gateway público foi atualizado com backup do script antigo.
  Backup da última mudança:
  `/usr/local/libexec/storm-msn-ha/playstor-snes.js.pre-test-toggle-20261106-025757.backup`.

**Nunca declarar o client original modificado, jogo em execução ou
áudio/vídeo restaurados antes de testes reais nessas funções.**
