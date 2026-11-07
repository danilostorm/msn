# Storm MSN 2009 — iniciador Edge WebView2 para jogos PlayStor

**Data:** 06/11/2026, desenvolvimento na branch `feat/wlm2009-original-fidelity`.

O objetivo segue sendo preservar a interface, os menus, os ícones e as
janelas **originais** do Windows Live Messenger 2009 (14.0.8117.0416).
Este componente é uma ponte **temporária e opcional** para jogos SNES,
não uma substituição visual do Messenger nem um patch do binário.

## Descoberta do navegador padrão

No Nexus, o Windows associa HTTPS a `BraveHTML`, embora Microsoft
Edge e Edge WebView2 Runtime 156 estejam instalados. Um link normal
`https://` no Messenger pode abrir o Brave. Não modificamos a
associação de navegador padrão.

## Componentes desenvolvidos e testados

- [StormEdgePlaystorLauncher.cs](StormEdgePlaystorLauncher.cs): programa
  nativo WinForms x86 cujo **único conteúdo de jogos** é renderizado
  por Microsoft Edge **WebView2**, com perfil independente no laboratório.
  Aceita `--catalog`, `--play 673`, ou `--uri stormmsn-game://play/673`.
  Não acessa credenciais MSN nem o processo `msnmsgr.exe`.
- [Register-StormMSNEdgeProtocol.ps1](Register-StormMSNEdgeProtocol.ps1):
  registra ou remove, **somente para o usuário atual**, o esquema
  `stormmsn-game://`. A chave é
  `HKCU\Software\Classes\stormmsn-game`; não muda `http`/`https`,
  navegador padrão ou registro HKLM. O recebedor só aceita
  `stormmsn-game://play/<ID-numérico>`, sem parâmetros, host arbitrário
  ou fragmentos.
- [Abrir-Jogos-Edge-Lab.cmd](Abrir-Jogos-Edge-Lab.cmd): comando simples
  para abrir o catálogo no motor Edge WebView2 a partir da pasta de
  laboratório do Nexus.

Binário compilado **somente no Nexus**:

`E:\StormMSN-Research\lab-native-2009\webview2-poc\build\StormEdgePlaystorLauncher.exe`

Atalho de laboratório:

`E:\StormMSN-Research\lab-native-2009\Abrir-Jogos-Edge-Lab.cmd`

## Testes realizados no Nexus

O programa foi compilado com C# .NET Framework em `/platform:x86`.

- `--selftest`: **PASS**, incluindo jogo numérico,
  rejeição de deep links malformados e bloqueio de navegação
  a hosts externos.
- `--play 673 --smoke`: **PAGE_LOADED** em
  `playstor.hoststorm.cloud`; `playRequested=true`,
  `loginVisible=true`, `shellVisible=false`. Não iniciou jogo
  porque não havia conta PlayStor autenticada.
- `--catalog --smoke`: **PAGE_LOADED** no catálogo Storm MSN.
- `--catalog --follow-first-game --smoke`: navegou do catálogo para
  o player PlayStor pelo botão **Jogar**, com
  `FinalHost=playstor.hoststorm.cloud`, `playRequested=true` e
  login legítimo exibido. Isso testa navegação, não emulação.
- O Windows recebeu o link
  `stormmsn-game://play/673`, iniciou exatamente um processo
  de laboratório e o teste o encerrou.
- O protocolo está instalado apenas no perfil
  `NEXUSLITE-PC\Administrator`.
- A associação HTTPS padrão permaneceu `BraveHTML`.

Relatórios locais, sem cookies, senhas, tokens, conteúdo de página
ou contatos MSN:
- `...\build\Edge-Launcher-Play673-Smoke.txt`
- `...\build\Edge-Launcher-Catalog-Smoke.txt`
- `...\build\Edge-Launcher-CatalogToGame-Smoke.txt`
- `...\build\Edge-UriBridge-Result.txt`.

## Catálogo: ativação opcional

O gateway `integrations/playstor-snes/playstor-snes.js` oferece um
modo **opt-in** acessível adicionando `edge=1` à URL do catálogo:

`https://msn.hoststorm.com.br/AppDirectory/Directory.aspx?edge=1`

No modo padrão, o usuário vê apenas o link HTTP normal
`Abrir no navegador` (não é garantidamente Edge).
No modo opt-in, o catálogo acrescenta
`Jogar com Edge WebView2`, que usa o
protocolo `stormmsn-game://play/<id>` e preserva o link convencional
como fallback. Busca e paginação mantêm `edge=1`.

**Atenção:** o botão opcional depende do iniciador instalado no
computador. Outros clientes MSN sem a ponte não devem usar esse botão.

### Registrar o protocolo para o usuário atual

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "E:\StormMSN-Research\lab-native-2009\webview2-poc\Register-StormMSNEdgeProtocol.ps1" -Action Verify
```

Para desfazer:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "E:\StormMSN-Research\lab-native-2009\webview2-poc\Register-StormMSNEdgeProtocol.ps1" -Action Uninstall
```

## Restrições e trabalho pendente

1. É necessário abrir uma conversa controlada do Messenger original
   e localizar `convdraweractivityhost` em DirectUI.
2. Integrar WebView2 **dentro do painel real** de jogos da conversa
   ainda não foi realizado. O iniciador disponível abre uma janela
   Edge WebView2 independente, apenas para validação funcional.
3. Para executar uma ROM real, a conta PlayStor precisa autenticar-se
   normalmente no perfil WebView2; nenhum bypass foi implementado.
4. Os convites MSNP/P2P preservam payloads nos testes, mas jogo
   multiplayer com dois contatos MSN ainda não está funcionando.
5. Voz/vídeo originais dependem de transporte/negociação próprios;
   não foram reativados por esta ponte de jogos.

**Segurança:** os binários originais WLM e os 55 arquivos protegidos
permanecem inalterados; nenhum executável Microsoft foi publicado.
