# Storm MSN / WLM2009 — DirectUI, Trident e PlayStor (06/11/2026)

## Escopo e limites

Desenvolvimento apenas na branch `feat/wlm2009-original-fidelity`, com Windows Live Messenger 2009 PT-BR **14.0.8117.0416** instalado no Nexus. A instalação original, seus binários Microsoft, temas, ícones e janelas não foram modificados.

Este relatório separa três etapas distintas: localização da superfície original DirectUI; reprodução segura de incorporação WebView2 sobre um controle Trident **em laboratório**; e teste de uma página de jogo real do PlayStor **sem autenticação**.

## 1. Superfície original identificada

A inspeção do recurso visual **UIB 920** de `msgsres.dll`, no laboratório local `E:\StormMSN-Research\analysis\resources\.rsrc\4010\920`, encontrou os identificadores:

- `convdrawerroot`
- `convdraweractivityhost`
- `p4gamecontainer`
- `p4appcontainer`
- `ActivityAreaRightTitleBarCont`
- `gamesdropdownbtn`

O Ghidra 12.1.4, executado em modo de leitura, mapeou referências x86:

- `convdraweractivityhost` (`0x004357FC`) referenciado por
  `FUN_00584349` (`0x00584377`) e
  `FUN_00584509` (`0x00584545`).
- `gamesdropdownbtn` (`0x0043328C`) referenciado pelo dispatcher
  `FUN_0056F11B` (`0x005707BA`).
- `GamesLobby` e configuração
  `LocalizedConfig/AppDirConfig/GamesBrowserURL` também presentes no executável.

As funções decompiladas indicam obtenção de um elemento DirectUI com
`FUN_0049A688`, seguida de operações de anexar/remover componentes da árvore DirectUI. Isso não garante que `convdraweractivityhost` possua HWND próprio; é necessário inspecioná-lo com uma **conversa original aberta**.

Script Ghidra: [MapNativeActivityHostReferences.java](MapNativeActivityHostReferences.java).

## 2. Detector seguro da hierarquia HWND

Criado [Inspect-WLM-NativeWindowTree.ps1](Inspect-WLM-NativeWindowTree.ps1), que usa apenas Win32 `EnumWindows`, `EnumChildWindows`, `GetWindowRect`, `GetClassName` e identificadores de processo. **Não lê textos, contatos, mensagens, senhas, pixels ou clipboard.**

Primeira execução na sessão gráfica 1 do Nexus:
- 44 nós Windows reconhecidos, nenhuma janela principal visível, `SafeToAttachWebView2=false`.

O iniciador original foi executado com nível `Limited`; não houve novo crash. Depois:
- `MSBLWindowClass`: 310 × 700 px;
- `Main Window Class`: 294 × 638 px;
- `DirectUIHWND`: 294 × 638 px;
- 57 nós Windows;
- uma janela principal nativa visível; **nenhuma conversa identificada**.
- `SafeToAttachWebView2=false` corretamente.

Apareceu um segundo processo `msnmsgr.exe` transitório durante a inicialização; na inspeção seguinte havia apenas um. Nenhum dado de conversa foi coletado.

## 3. Incorporação no HWND real de Trident, mas ainda em laboratório

Criado [StormTridentChildHost.cs](StormTridentChildHost.cs), compilado x86 com C#/.NET Framework no Nexus.

O programa cria **seu próprio** `System.Windows.Forms.WebBrowser` (Trident), carrega o catálogo público Storm MSN, localiza um filho **`Internet Explorer_Server`** pertencente exclusivamente ao processo de laboratório, inicia o [StormWebView2EmbedGuest.cs](StormWebView2EmbedGuest.cs) e usa `SetParent` para incorporá-lo no HWND do Trident. Não aceita HWND de outra aplicação nem acessa `msnmsgr.exe`.

Teste real no Nexus:

| Critério | Resultado |
|---|---|
| `Internet Explorer_Server` presente | **True** |
| `SetParent` e verificação por `GetParent` | **True** |
| Página de catálogo PlayStor aberta | **True** |
| WASM mínimo compilado/instanciado no WebView2 incorporado | **True** |
| Contexto WebGL no WebView2 | **True** |
| Tamanho inicial da área | 834 × 601 |
| Tamanho após resize | 914 × 651 |
| Filho coincide exatamente com o HWND do Trident após resize | **True** |
| Código de saída da tarefa de teste | 0 |
| Jogo lançado | **Não** |

Log local: `E:\StormMSN-Research\lab-native-2009\webview2-poc\build\TridentHostReport.txt`.

**Limite:** este `Internet Explorer_Server` pertence ao programa de laboratório, **não** ao Messenger 2009 real.

## 4. Teste do jogo PlayStor 673 sem credenciais

A URL `https://playstor.hoststorm.cloud/?game=673` respondeu HTTP 200. É uma aplicação web dinâmica; HTTP 200 sozinho não comprova o player rodando.

Para inspecionar apenas estado público, foi criado [StormPlaystorGameProbe.cs](StormPlaystorGameProbe.cs) com perfil WebView2 próprio, sem usar login/cookies do usuário, sem clicar em botões e sem salvar conteúdo.

O mesmo teste foi incorporado por [StormTridentGameHost.cs](StormTridentGameHost.cs) ao navegador Trident de laboratório. Resultados do DOM após o carregamento:

- `passwordInputPresent=true`;
- `canvasCount=0`;
- `visibleCanvasCount=0`;
- `gamePlayerLikely=false`;
- `WebAssembly` e `fetch` presentes na engine moderna;
- `GuestAttachedToIEServer=true`;
- `ChildSizeMatches=true` após redimensionamento;
- `GameLaunched=false`.

O relatório não conclui que o PlayStor inteiro requer senha em todos os contextos; **apenas** que, nesse perfil novo e não autenticado, apareceu um campo de senha e não houve inicialização detectável do player.

Logs locais:
- `...\build\TridentGameHostReport.txt`
- `...\build\TridentEmbeddedGameGuestReport.txt`

## 5. Consequências para a integração definitiva

O caminho técnico agora é concreto:

1. Utilizar o **botão original** `gamesdropdownbtn` e as rotinas de DirectUI, sem recriar a janela WLM.
2. Quando o Messenger original realmente abrir uma conversa/atividade, detectar **se** ele cria um `Internet Explorer_Server` dentro da área de jogos. Se não houver HWND dedicado, investigar a geometria de `convdraweractivityhost`.
3. Hospedar e redimensionar o WebView2 **somente** na superfície comprovadamente pertencente ao jogo, preservando controles de chat, menus e contatos.
4. Preservar a segurança da autenticação: sessão própria ou SSO legítimo com tokens de curta duração no PlayStor, sem reutilizar ou armazenar a senha MSN em código ou em URLs.
5. Testar um jogo com usuário de teste autorizado e validar gamepad, áudio, foco, fechamento de conversas e sincronização multiplayer.

Não foi aplicado patch ao executável ou às DLLs originais. Ainda **não** há jogo ou chamada real funcionando dentro do WLM.

## 6. Entrega

- Todos os scripts e fontes de laboratório estão na branch de desenvolvimento.
- Os executáveis e SDKs compilados permanecem **exclusivamente no Nexus**:
  `E:\StormMSN-Research\lab-native-2009\webview2-poc\build`.
- Os binários Microsoft permanecem privados no Nexus; não foram enviados ao GitHub.
- O programa de produção e os bancos não foram alterados.
