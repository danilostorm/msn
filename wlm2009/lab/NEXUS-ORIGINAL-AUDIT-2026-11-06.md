# Storm MSN — auditoria do cliente original no Nexus (06/11/2026)

## Escopo e restricao

**100% da aparencia de Windows Live Messenger 2009 PT-BR, sem redesenho.**
Esta auditoria utiliza a instalacao **original existente** e so le os arquivos.
Nada foi substituido, patch aplicado, injetado ou executado por Ghidra/REA.

Maquina: `NEXUSLITE-PC` (Windows 11 Pro). Acesso remoto foi restaurado em
06/11/2026. Cliente instalado em
`C:\Program Files (x86)\Windows Live`.

## Integridade comprovada no Nexus

A comparacao foi realizada por SHA-256 entre os binarios instalados e
`E:\StormMSN-Research\original`:

| Arquivo | SHA-256 | Resultado |
|---|---|---|
| `Messenger/msnmsgr.exe` | `16660063313576d528e69bdbedb69e0c213b31cba0fae579f3e2482a00316f75` | igual |
| `Messenger/msgsres.dll` | `39be9f1a387ea1d861a24a2454f3ddedd957e975d9a219ecd36d2ed7fcfbb29d` | igual |
| `Messenger/uxcore.dll` | `3f2cb92497f5f6e46f4becc7d3f133094355e0211dbba1f87bcccbfe4ea405ab` | igual |
| `Messenger/msgrvsta.thm` | `7023376cc5a665e686bc20b01aaa333562d66428a2b5d17fed47bde6382b5815` | igual |
| `Messenger/msgslang.14.0.8117.0416.dll` | `e1fed8745ca6808403e64c6aa3b51e0572b0809a576895951af55658155ceb33` | igual |

Versao do executavel: `14.0.8117.0416`. A comparacao **nao certifica**
que a copia de referencia e uma distribuicao Microsoft intocada;
ela comprova identidade byte a byte entre a instalacao e a referencia
atual, possivelmente ja pre-patcheada para Switcher.

Gerada baseline de **55 arquivos protegidos** em
`E:\StormMSN-Research\analysis\integrity\WLM2009-original-install-baseline.json`,
com verificacao subsequente OK. O script de integridade reside apenas
em `E:\StormMSN-Research\analysis\integrity`, nao no diretorio do WLM.

## Recursos visuais UIB reais

Extraidos da DLL original `msgsres.dll`, em
`E:\StormMSN-Research\analysis\resources\.rsrc\4010`:

| ID | Tela | Tamanho do recurso | Identificadores reais confirmados |
|---|---|---:|---|
| `947` | Login | 15049 bytes | `idEmailInput`, `idPasswordInput`, `idSignInBtn`, `idUserTileArea` |
| `923` | Contatos | 21205 bytes | `idMeArea`, `idFriendlyName`, `UXContacts`, `idMeAreaUserTile` |
| `920` | Conversa | 49672 bytes | `convinput`, `idBuddyFriendlyName`, `idYouUserTile`, `idMeUserTile` |
| `44901` | Contato, modelo 1 | 5705 bytes | `UXContacts`, `ContactStatus` |
| `44902` | Contato, modelo 2 | 6075 bytes | `UXContacts`, `ContactStatus` |

Todos com assinatura `UIB`. Identificadores foram localizados no
conteudo binario original, **nao reproduzidos como XAML**.

## Ghidra/REA — analise real, somente leitura

- Ghidra **12.1.4**, projeto `E:\StormMSN-Research\analysis\StormMSN`;
  executado `-process msnmsgr.exe -readOnly -noanalysis` com
  `InspectOriginalUi.java`, commitado nesta branch.
- Resultado do Ghidra: **PE x86, 32-bit, little endian**,
  base `0x00400000`, 21.395 funcoes previamente reconhecidas,
  1.955 simbolos externos, 312 com nomes que correspondem ao filtro
  amplo de termos UI (inclui falsos positivos `Create*`).
- Foram observados imports como `CreateWindowExW`,
  `UpdateLayeredWindow`, `GdipDrawImageI`, `GdipCreateBitmapFromResource`,
  `DrawTextW`, `SetWindowPos`. Isso nao equivale a decodificar
  a totalidade da hierarquia UIB nem comprova como cada tela e desenhada.
- Log local: `E:\StormMSN-Research\analysis\integrity\Ghidra-WLM-Original-UI.log`.
  Execucao terminou com `GHIDRA_EXIT:0` e `AUDIT_COMPLETE_READ_ONLY`.
- REA Agents **6.8.0**, `doctor --provider ghidra --json`, reportou
  `healthy:true` para o provedor Ghidra; integrações opcionais
  (Hopper, IDA, etc.) nao configuradas.
- `rea inspect-artifact` verificou integridade do PE local com
  SHA-256 `16660063313576d528e69bdbedb69e0c213b31cba0fae579f3e2482a00316f75`.
  Essa operacao e de inventario, nao decompilacao de codigo.

## Switcher e rede

Ambos `Messenger/msnmsgr.exe-escargot.ini` e
`Contacts/wlcomm.exe-escargot.ini` estao configurados com:

```ini
[options]
type = msn
passporturls = 1
server = im.hoststorm.com.br
configserver = msn.hoststorm.com.br
```

Testes realizados **a partir do Nexus**:

- TCP `im.hoststorm.com.br:1863` OK.
- TCP `im.hoststorm.com.br:1864` OK.
- HTTPS `https://msn.hoststorm.com.br/` HEAD 200.
- HTTPS `https://msn.hoststorm.com.br/etc/MsgrConfig` HEAD 200.

Os processos `msnmsgr.exe` e `wlcomm.exe` estavam em execucao,
mas SSH nao forneceu janelas graficas acessiveis (`MainWindowHandle=0`).
Nao foram digitadas credenciais, testado login real nem tiradas
capturas de tela da sessao do usuario.

## Conclusao e proximos testes

A base de recursos originais esta preservada e conectada ao endereco do
Storm MSN. Nao e necessario nem desejado construir outra aparencia em WPF.
Para alegar **100% visual** em cada janela e estado, usar a UI
**nativa original**, sem alterar recursos, e verificar eventual impacto
de tema e escala DPI no ambiente de execucao.

**Pendente:** login completo SSO interativo, contatos, janelas reais,
anexos, voz/video e jogos — eles dependem de compatibilidade de protocolo,
servicos externos e provas no cliente, nao de recriacao grafica.

Nenhum arquivo da instalacao do cliente original foi modificado pela auditoria.
