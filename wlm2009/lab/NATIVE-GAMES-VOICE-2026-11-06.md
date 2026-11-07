# Storm MSN — engenharia reversa nativa / Games, vídeo, voz e P2P

**Data:** 2026-11-06  
**Alvo:** Windows Live Messenger 2009 PT-BR `14.0.8117.0416`, executável e recursos originais.  
**Regra:** preservar 100% da aparência nativa. NÃO recriar em WPF/Electron e NÃO substituir `msgsres.dll` ou `UXCore.dll` sem necessidade.

## 1. Recursos nativos no Messenger original

A análise de recursos da `msgsres.dll`, tipo `4010`, verificou:
- **UIB 920**, conversa, 49.672 bytes: `gamesdropdownbtn`,
  `p4gamecontainer`, `convdraweractivityhost`,
  `videocallText`, `WebCamButtonIcon`, `videocontainer`,
  `VoiceIMinputarea`, `audiocontrol`, `sendfilebtn`.
- **UIB 930 e 932**, 6.472 bytes cada: `ActivityButton`,
  `GamesLobby`, `ActivityList`, `LocalActivity`.
- **UIB 945**, 12.416 bytes: `youvideocallmenuitem`,
  `videocallmenuitem`, `webcammenuitem`, `CallComputerMenuItem`,
  `LegacyFileTransferMenuItem`.
- **UIB 936/960**: interfaces de webcam e câmera.

**Isso confirma recursos visuais e controles; não garante funções de
rede operacionais ou jogos executáveis no navegador antigo.**

## 2. Referências encontradas com Ghidra 12.1.4

Scripts de pesquisa sem modificar a instalação:
- `FindOriginalFeatureReferences.java`
- `DecompileOriginalFeaturePaths.java`

Análise do `msnmsgr.exe` original, x86 32-bit, em modo `-readOnly -noanalysis`.

| Recurso/função identificada | Função em análise |
|---|---|
| `GamesLobby` / `gamesdropdownbtn` | `FUN_0056f11b` |
| `P4Game` | `FUN_005e0473`, `FUN_005e049f` |
| Área de atividades | `FUN_00584349`, `FUN_00584509` |
| Menu de chamadas | `FUN_0056c995` |
| `VoiceIM` | `FUN_0056358f`, `FUN_0055c634` |

As funções foram decompiladas em um projeto de investigação.
Os logs locais com os resultados permanecem em
`E:\StormMSN-Research\analysis\integrity\`.

Duas rotinas da área de atividades fazem referência a
`convdraweractivityhost` e operações do DirectUI. O código
específico para iniciar jogos e serviços A/V ainda precisa ser isolado.
**Nenhuma dessas funções foi alterada ou patch aplicada ao cliente.**

## 3. GamesBrowserURL e catálogo PlayStor

O `MsgrConfig.wlm.14.xml` já disponibiliza, para a versão original:

```xml
<GamesBrowserURL>https://msn.hoststorm.com.br/AppDirectory/Directory.aspx?from=wlm2009</GamesBrowserURL>
```

O AppDirectory real respondeu:
- `GET /AppDirectory/Directory.aspx?from=wlm2009`: HTML de jogos do Storm MSN.
- `GET /AppDirectory/AppDirectory.asmx`: `AppDir` com **100 entradas** SNES.
- `POST /AppDirectory/AppDirectory.asmx` com `SOAPAction: GetAppEntry`
  para o AppID 673: resposta `GetAppEntryResponse`, com ID e
  URL iguais aos do catálogo.
- `GET /etc/MsgrConfig?ver=14.0.8117.0416`: aponta para o catálogo correto.

`probe_games_appdir.py --live` executado da Oracle passou
sem login, jogo iniciado ou alteração de dados. Oito testes offline
também passaram; eles detectam configuração ausente, SOAP inválido,
URLs de outros hosts e IDs inseguros.

**Limitações:** a URL de jogo aponta para
`https://playstor.hoststorm.cloud/`, que requer navegador moderno;
o Internet Explorer embutido do Messenger antigo não executa jogos
WASM modernos. O painel nativo pode carregar o catálogo,
mas isso não demonstra jogo rodando internamente nem multiplayer
entre contatos.

Documentação histórica de terceiros sobre o contrato:
- https://gitlab.com/escargot-chat/server/-/wikis/activities
- https://wiki.nina.chat/wiki/Protocols/MSNP/Activities/SDK/Appdir/Directory

## 4. P2P, voz e convites legados

O switchboard real do Storm MSN em `front/msn/msnp_sb.py` preserva
`MessageData.front_cache['msnp']` com os bytes de cada mensagem MSN.
Este caminho permite repassar **byte a byte** convites legados e
`application/x-msnmsgrp2p` entre clientes compatíveis. Não é
implementação de codec ou de servidor de áudio/vídeo.

Foi encontrado um defeito no parser: MIME malformado podia deixar
`headers` indefinido e um datacast sem `ID` podia causar exceção.
Correções mantidas **somente nesta branch**:
- inicialização segura e tratamento de MIME sem cabeçalho;
- datacast inválido tratado como não suportado, sem exceção;
- UTF-8 inválido tratado sem encerrar a sessão;
- preservação integral dos bytes legados em `front_cache['msnp']`.

**11 testes isolados aprovados** para convites de jogo e de voz,
P2P com bytes binários, nudge, MIME incompleto e texto. Os testes
não utilizam conta real nem endpoint de produção.

Estes testes não comprovam que voz/vídeo funcionam: falta
negociação P2P completa, transporte de mídia, compatibilidade
com codificadores e serviços de relay.

## 5. Cópia nativa de laboratório no Nexus

A instalação original foi replicada (somente arquivos de programa) em:

`E:\StormMSN-Research\lab-native-2009\Windows Live`

- **60 arquivos**, **42,87 MB**.
- SHA-256 verificado **60/60**, **zero divergências**.
- Manifesto local:
  `E:\StormMSN-Research\lab-native-2009\sha256-comparison.json`.
- Não copiar os binários proprietários para GitHub.
- Qualquer futura modificação de binário deve ser testada
  **nessa cópia isolada**, com SHA do arquivo alvo,
  backup, registro de alteração e recuperação garantida.
- O laboratório é um *clone verificado*, **não** uma versão
  com patches novos instalados. A decompilação não gera o
  código-fonte original Microsoft.

## 6. Estado seguro

- A instalação original `C:\Program Files (x86)\Windows Live`
  não foi modificada nesta rodada.
- Nenhum serviço Docker ou banco de produção foi alterado.
- Alterações de servidor e testes estão somente na branch
  `feat/wlm2009-original-fidelity`.
- Próximo passo para integração real: reproduzir um clique nativo
  Games com uma conta de teste isolada, identificar requisicões
  emitidas e validar convite de uma segunda conta;
  só depois implementar endpoints/relay que faltarem.
- Para voz/vídeo, mapear o fluxo P2P e a sinalização na
  source original e testar em duas contas descartáveis antes de
  pensar em patching de DLL.

**Visual original preservado. Jogos e chamadas não declarados concluídos.**
