# Storm MSN 2009 — Edge WebView2 e links diretos do PlayStor

Data: **06/11/2026 (Brasil)**  
Branch de desenvolvimento: `feat/wlm2009-original-fidelity`.

**Princípio:** preservar o Windows Live Messenger 2009 original (executável,
temas, controles, ícones e sons). Utilizar Microsoft Edge / WebView2
para renderizar jogos modernos. **Não** instalar outro IE nem usar
Trident para rodar jogos.

## 1. Descoberta importante: duas rotas distintas no PlayStor

O JavaScript público `standalone.js` do PlayStor trata:

- `?game=<id>`: abre a página de **detalhes** do jogo depois da
  autenticação;
- `?play=<id>`: chama
  `window.StormFlixGamePlayer.open({id})` para **iniciar o player**
  depois da autenticação.

Isso revelou por que o catálogo anterior, que usava `?game=`, não
representava um clique direto de jogar.

## 2. Correção já publicada somente no gateway do catálogo

O arquivo-fonte versionado
`integrations/playstor-snes/playstor-snes.js` teve **três alterações
pontuais**:
1. Link HTML do catálogo: `?game=<id>` para `?play=<id>`;
2. Rótulo do botão: `Jogar no Microsoft Edge`, com aviso sobre login
   e integração nativa ainda não concluída;
3. Respostas de `AppDirectory.asmx`: URL `?play=<id>`.

Os testes em `integrations/playstor-snes/test-catalog.js` cobrem
HTML, XML/SOAP, URLs diretas e sanitização.
Testes executados na Oracle e por GitHub Actions Windows, com êxito.

O serviço é dedicado ao catálogo, não ao login nem ao switchboard:
`storm-msn-snes-catalog.service` na Oracle,
`127.0.0.1:18590`, atrás do túnel Cloudflare/ingresso público
`msn.hoststorm.com.br/AppDirectory/*`.

A implantação fez **backup do arquivo anterior** e atualizou apenas:
`/usr/local/libexec/storm-msn-ha/playstor-snes.js`.
A primeira tentativa foi revertida automaticamente porque a checagem
aconteceu antes de o serviço voltar a escutar (corrida de startup).
A segunda tentativa aguardou a saúde e **foi aprovada**.

Backup da implantação aprovada:
`/usr/local/libexec/storm-msn-ha/playstor-snes.js.pre-edge-20261106-023352.backup`.

Hash SHA-256 do script atualizado:
`de49fbaeab2268045d3e0a24e2e1687e06f1b2e7e5b29e5bb5dd901c161ce263`.

A verificação retornou:
- systemd `active`;
- `/healthz`: `ok:true`;
- catálogo local com `?play=673`;
- SOAP AppDirectory local com `<URL>.../?play=673</URL>`;
- catálogo público com `?play=673`.

**Limite:** o link direto no catálogo utiliza o navegador moderno do
sistema. A integração incorporada ao painel nativo do MSN
**ainda não foi publicada**.

## 3. Novo guardião de superfície DirectUI sem Internet Explorer

Criado [StormEdgeSurfaceGuard.cs](StormEdgeSurfaceGuard.cs), compilado
em C# x86, usando Win32 e Windows UI Automation (somente leitura).

O utilitário valida antes de permitir qualquer futura incorporação:
- nome, caminho e hash SHA-256 do executável original
  `msnmsgr.exe`;
- sessão gráfica e janela `MSBLWindowClass`;
- área de conversa de tamanho suficiente (rejeita janela de contatos);
- elemento UIA com AutomationId `convdraweractivityhost`;
- elemento pertencente ao mesmo PID, visível, geometria bem delimitada;
- recusa valores NaN/Infinity, áreas que cobrem a janela inteira,
  regiões pequenas ou fora das bordas.

**Falha fechada:** o código é intencionalmente de diagnóstico:
`AttachAllowed=false`, mesmo se um candidato existir, até validar
em teste real. Não injeta DLL nem chama `SetParent` na janela MSN.
O requisito visual pixel a pixel permanece intacto.

Oito casos geométricos aprovados via `--selftest` no Nexus
(incluindo um bug identificado e corrigido na comparação com NaN).
O modo `--scan` foi executado na sessão gráfica 1:
- cliente original reconhecido pelo SHA;
- nenhuma superfície de jogos segura encontrada naquele momento;
- nenhuma modificação de processo ou dados.

Executable privado de laboratório:
`E:\StormMSN-Research\lab-native-2009\webview2-poc\build\StormEdgeSurfaceGuard.exe`

Relatório local:
`...\build\StormEdgeSurfaceGuard-RealClient.txt`

## 4. Edge WebView2 testado com URL direta de jogo

[StormPlaystorGameProbe.cs](StormPlaystorGameProbe.cs) foi alterado
para navegar a `https://playstor.hoststorm.cloud/?play=673` em um
perfil WebView2 totalmente isolado.

Uma navegação de janela principal fora de
`https://playstor.hoststorm.cloud` é rejeitada. O componente não
lê senhas, tokens, cookies, textos pessoais ou mensagens do WLM.

Resultado real no Nexus:
- `State=OK`;
- `playRequested=true`;
- `WebAssembly` e `fetch` presentes;
- `loginVisible=true`;
- `shellVisible=false`;
- `playerApiPresent=false`;
- `canvasCount=0`;
- `GameLaunched=false`.

Isso indica que a rota correta foi recebida, mas uma sessão legítima
do PlayStor ainda é necessária antes de iniciar o jogo. O código
público mostra que, após autenticação, `start()` inicializa a área
de jogos e solicita o lançamento com `?play=<id>`.

Relatório local:
`E:\StormMSN-Research\lab-native-2009\webview2-poc\build\Playstor-DirectPlay-Edge-Report.txt`.

## 5. Pendências reais

- Abrir uma conversa de **teste** no cliente MSN 2009 original para
  identificar a geometria do `convdraweractivityhost` real. A
  janela normal de contatos não serve como host de jogos.
- Determinar se o DirectUI expõe a geometria via UI Automation ou
  se precisa de uma pequena adaptação no binário **de laboratório**.
- Incorporar Edge WebView2 somente na área de jogos, sem cobrir chat
  ou barra original. O protótipo de SetParent entre janelas do próprio
  laboratório foi validado anteriormente; não é ainda uma integração WLM.
- Fazer login com uma **conta descartável autorizada** do PlayStor e
  validar jogo realmente iniciado, áudio, gamepad, fechamento e foco.
- Implementar convites/sessões multiplayer no protocolo MSN;
  não confundir entrega byte a byte de um convite com partida iniciada.

**Não** foi feito bypass de login, não foi copiada nenhuma ROM
ou credencial, e o cliente Microsoft original permanece intacto.
