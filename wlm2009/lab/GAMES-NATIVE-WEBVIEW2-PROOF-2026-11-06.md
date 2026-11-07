# Storm MSN — teste de jogos nativos, Trident e WebView2 (Nexus)

Data: **2026-11-06**. Branch: **feat/wlm2009-original-fidelity**.

Regra inalterada: utilizar a interface **Windows Live Messenger 2009
14.0.8117.0416 original** e adaptar apenas o funcionamento. Nao criar outra
interface no lugar do cliente. Nao copiar binarios originais Microsoft
para o GitHub.

## 1. Teste de protocolo entre duas sessoes simuladas

Arquivo: `wlm2009/lab/tests/test_two_client_native_relay.py`.

Foram extraidos por AST do servidor real:
- `MSNPCtrlSB._m_msg` (mensagem de entrada do switchboard);
- `ChatEventHandler.on_message` (mensagem encaminhada ao outro cliente);
- `messagedata_from_msnp` / `messagedata_to_msnp`.

O teste simula um par emissor/receptor e exercita as rotinas reais,
com transportes e contas falsos. Confirmou:
- convite de jogo (MIME `text/x-msmsgsinvite`) preservado byte por byte;
- convite de voz preservado byte por byte;
- dados P2P arbitrarios, inclusive nao UTF-8, sem corrupcao;
- nudge e indicacao de digitacao;
- rejeicao de excesso de tamanho e ack P2P proibido;
- MIME incompleto nao derruba a sessao simulada.

**18 testes aprovados** na Oracle: onze regressões de parser,
sete do switchboard. Isso **nao** equivale a dois clientes WLM reais
interagindo com um servidor autenticado.

## 2. Ghidra — comando original GamesLobby

O Ghidra abriu `msnmsgr.exe` original, modo somente leitura,
no projeto isolado `E:\StormMSN-Research\analysis\StormMSN`.

Scripts:
- `InspectGamesLobbyCallSite.java`
- `InspectNativeGamesCommand.java`

Pontos estaticos observados:

| Item | Resultado |
|---|---|
| Dispatcher nativo | `FUN_0056F11B` |
| Case associado a Games | `0x9EAA` |
| Rotina subsequente | `FUN_0056618B` |
| String de configuracao | `LocalizedConfig/AppDirConfig/GamesBrowserURL` |
| Referencia ao controle | `gamesdropdownbtn` |
| Area de atividades | `convdraweractivityhost` |
| Categoria/identificador | `GamesLobby` |

O fluxo acessa a configuracao de jogos e chama rotinas de DirectUI e de
atividades. Identificar referencias e decompilar o dispatcher **nao**
prova que uma operacao de lancamento tenha sido totalmente reconstruida
ou que um patch esteja pronto.

## 3. Catalogo no mecanismo antigo do Windows (Trident)

Ferramenta isolada: `Test-NativeTridentGamesBrowser.ps1`.

Executada na **sessao grafica 1** do Nexus em janela de laboratorio
invisivel, com o controle `System.Windows.Forms.WebBrowser`, nao dentro
do Messenger instalado. Nao usa nem altera cookies ou mensagens
pessoais deliberadamente; nao salva conteudo da pagina.

- Documento HTML do catalogo carregou (`ReadyState=Complete`).
- Texto PlayStor encontrado no DOM.
- **24** links PlayStor detectados na pagina visivel de catalogo.
- Verificacao JS no proprio componente:
  - `typeof WebAssembly = "undefined"`;
  - `typeof fetch = "undefined"`;
  - `typeof WebSocket = "function"`;
  - Canvas `getContext = "function"`.

**Implicacao:** o catalogo e renderizavel no engine legado, mas o
emulador SNES do PlayStor, que requer WebAssembly, nao roda nele.

## 4. Prova de conceito do WebView2 moderno

O Nexus ja tem **Microsoft Edge WebView2 Runtime 156.0.4314.58**
instalado. O projeto isolado baixou o SDK oficial NuGet
`Microsoft.Web.WebView2 1.0.4314.35`, no laboratorio:

`E:\StormMSN-Research\lab-native-2009\webview2-poc`

SHA-256 do pacote NuGet obtido no host:
`90778deb1b77e36292828b4b5833c9255c27533f40e0ddd55891ae718944edc4`.

Fonte do prototipo:
`wlm2009/lab/StormWebView2Lab.cs`.

Foi compilado com o compilador .NET Framework existente no Nexus,
**plataforma x86**, usando DLLs SDK locais e WebView2Loader x86. O
executavel compilado de laboratorio esta em:

`E:\StormMSN-Research\lab-native-2009\webview2-poc\build\StormWebView2Lab.exe`

Teste controlado (tarefa agendada temporaria, removida apos uso):
- Sessao interativa 1, janela isolada invisivel;
- perfil de navegador separado em `isolated-profile` local ao laboratorio;
- apenas catalogo publico `msn.hoststorm.com.br` permitido;
- popup de novas janelas bloqueado;
- `Status=OK`, `ElapsedMilliseconds=3740`;
- JS respondeu:
  `WebAssembly:"object"`,
  `fetch:"function"`,
  `WebSocket:"function"`,
  `canvas:"function"`,
  `PlayStorPresent:true`.
- Finalizacao normal com codigo de saida 0.

**Importante:** este prototipo e uma **janela independente**;
ainda nao usa `SetParent`, injecao de DLL ou patch
para entrar no `convdraweractivityhost` do Messenger.
Nao executa jogos e nao testa multiplayer.
O objetivo foi provar que o runtime moderno no mesmo Nexus pode
exibir o catalogo e oferece APIs necessarias a um jogo WASM.

## 5. Ambiente preservado

- `msnmsgr.exe` e `wlcomm.exe` estavam ativos apos os testes.
- **55 arquivos protegidos** da instalacao original mantiveram o SHA.
- Copia de laboratorio do WLM 2009 permaneceu separada, sem patches.
- Nenhum processo `StormWebView2Lab.exe` residual encontrado.
- Nenhuma tarefa agendada temporaria `StormMSN-*` residual encontrada.
- Nenhum servico Docker de producao, banco ou conta foi alterado.

## 6. Para recuperar Jogos 100% dentro do MSN original

O caminho tecnicamente promissor e aproveitar o menu/controles originais
`GamesLobby`/`gamesdropdownbtn` e a area nativa
`convdraweractivityhost`, e **hospedar** nela um controle moderno para
o jogo. O teste de WebView2 prova o runtime, **nao** a incorporacao
interprocessos ao DirectUI original.

Etapas ainda necessarias:
1. Realizar login controlado de duas contas de teste no WLM original;
2. Observar abertura da janela nativa de conversa e da area de jogos;
3. Localizar HWND efetivo do painel de atividades (podem existir
   multiplos componentes DirectUI sob um HWND, exigindo outra forma
   de hospedagem);
4. Testar embedding/posicionamento em **copia isolada**,
   sem sobrepor contatos ou alterar recursos originais;
5. Implementar sincronizacao dos convites e sessoes de jogo
   entre contatos, e validar execucao e controles de input.
6. Se o WebView2 nao puder ser hospedado com fidelidade,
   avaliar renderizacao remota e outras alternativas.

O resultado atual nao e um cliente Microsoft modificado nem prova
de jogo funcionando dentro do WLM, e sim uma base reproduzivel
para implementacao segura.
