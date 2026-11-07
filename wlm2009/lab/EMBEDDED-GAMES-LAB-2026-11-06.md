# Storm MSN — laboratório de incorporação nativa do PlayStor no Windows

**Data:** 2026-11-06  
**Branch:** `feat/wlm2009-original-fidelity`  
**Ambiente:** Nexus, sessão gráfica 1, Windows 11, processos x86.  
**Objetivo:** provar a técnica de hospedar WebView2 em uma área nativa, mantendo o Windows Live Messenger 2009 original sem redesenho.

## 1. Resultado comprovado

Foram criados **dois executáveis próprios de laboratório** (C#/.NET Framework 4.8, x86), ambos fora da instalação do MSN:

- `StormNativeEmbedHost.exe`: abre uma janela nativa Win32/WinForms própria e um painel filho.
- `StormWebView2EmbedGuest.exe`: abre WebView2 em outra instância/processo, com perfil isolado.

O host localiza **somente a janela pertencente ao processo-filho que ele próprio iniciou**, altera o estilo Win32 para `WS_CHILD`, usa `SetParent` para incorporar a janela no painel de laboratório e controla o tamanho com `SetWindowPos`.

Em teste remoto real no Nexus:

| Verificação | Resultado |
|---|---|
| Compilação dos dois programas x86 | OK |
| `SetParent`: `GetParent(guest)==panel` | **True** |
| Catálogo público PlayStor no WebView2 incorporado | Carregado |
| WebAssembly disponível | True |
| Compilação e instanciação real de módulo WASM mínimo | **True** |
| Contexto gráfico WebGL | **True** |
| Área inicial | **734 x 551 px** |
| Área após simular redimensionamento | **830 x 615 px** |
| Tamanho final da janela filha | **830 x 615 px** |
| Filho continua anexado após resize | True |
| Código da tarefa de laboratório | 0 |
| Tempo do último teste | **1.708 ms** |
| Alteração em arquivos/processos Microsoft | **Não** |
| Jogo SNES iniciado | **Não** |

O módulo WASM de teste é um módulo vazio de oito bytes compilado e instanciado pelo próprio JavaScript do WebView2; não é um emulador nem um jogo.

Os relatórios locais são:
- `E:\StormMSN-Research\lab-native-2009\webview2-poc\build\EmbeddedHostReport.txt`
- `E:\StormMSN-Research\lab-native-2009\webview2-poc\build\EmbeddedGuestReport.txt`

## 2. Fontes de laboratório no GitHub

- [`StormNativeEmbedHost.cs`](StormNativeEmbedHost.cs)
- [`StormWebView2EmbedGuest.cs`](StormWebView2EmbedGuest.cs)
- [`StormWebView2Lab.cs`](StormWebView2Lab.cs), primeiro experimento independente
- [`Test-NativeTridentGamesBrowser.ps1`](Test-NativeTridentGamesBrowser.ps1), auditoria do mecanismo antigo
- [`InspectNativeGamesCommand.java`](InspectNativeGamesCommand.java), Ghidra no dispatcher original
- [`GAMES-NATIVE-WEBVIEW2-PROOF-2026-11-06.md`](GAMES-NATIVE-WEBVIEW2-PROOF-2026-11-06.md), fase anterior

Os executáveis compilados, perfis locais, SDK NuGet e binários originais Microsoft **não são enviados para o GitHub**.

## 3. Importante: não foi acoplado ao Messenger real

A implementação de `SetParent` acima é um experimento de duas janelas **inteiramente criadas pelo laboratório**; o código rejeita outro executável e não aceita HWND arbitrário. **Nenhum processo `msnmsgr.exe` foi manipulado.**

A última inspeção de janelas na sessão gráfica 1 encontrou `msnmsgr.exe` e `wlcomm.exe` ativos, com 35 janelas/objetos registrados no processo, **mas nenhuma janela de conversa visível** naquele momento. Não é seguro inferir o retângulo do jogo em `convdraweractivityhost` sem uma conversa de teste.

O Messenger original utiliza recursos DirectUI; o componente `convdraweractivityhost` pode não possuir seu próprio HWND. Encaixar um navegador por `SetParent` em uma janela principal `MSBLWindowClass` sem descobrir a geometria correta **pode cobrir botões, contatos e chat** e não atende ao requisito de fidelidade pixel a pixel.

## 4. Por que WebView2

O controle Trident/IE do Windows carrega o catálogo HTML, porém na sessão real testada devolveu:

- `typeof WebAssembly === "undefined"`
- `typeof fetch === "undefined"`

O WebView2 Runtime 156 do Nexus retornou:

- `typeof WebAssembly === "object"`
- `typeof fetch === "function"`
- módulo WASM criado e instanciado: `true`
- contexto WebGL: `true`
- catálogo PlayStor: disponível no DOM.

O uso do WebView2 **apenas na superfície de jogos** permite preservar os desenhos, menus e recursos originais do Messenger; a integração real ainda demanda prova de layout, foco, redimensionamento, entrada do teclado/mouse e o fluxo de convites.

## 5. Próximo experimento antes de patch

1. Abrir uma conversa com **contas descartáveis de teste** no WLM 2009 original, em ambiente controlado.
2. Invocar o botão original `Games`/`gamesdropdownbtn`.
3. Inspecionar somente o HWND, as dimensões e a hierarquia de janelas/DirectUI do componente `convdraweractivityhost`, sem coletar nomes, senhas, contatos ou mensagens.
4. Medir se há HWND filho dedicado ou se será necessário obter o retângulo de um elemento DirectUI por métodos internos.
5. Só então testar incorporação em **cópia isolada do cliente**, com restaurabilidade e sem substituir a UI.
6. Testar gamepad, áudio e a sincronização de sessão/convidados entre dois clientes reais.

**Estado atual: prova de conceito da incorporação entre processos aprovada; acoplamento ao WLM real, execução de jogo, voz e vídeo não concluídos.**
