# Auditoria da aparência do Windows Live Messenger 2009

Objetivo: aproximar a interface **WLM 14.0.8117.0416 (pt-BR)** sem alterar o executável instalado, mantendo o backend moderno do Storm MSN. Este documento é uma auditoria de fontes e medidas preliminares, **não uma certificação pixel a pixel**.

## Evidência do cliente original no Nexus

Diretório de referência: \`E:\StormMSN-Research\original\`. Binários preservados: \`msnmsgr.exe\`, \`msgsres.dll\`, \`msgslang.14.0.8117.0416.dll\`, \`uxcore.dll\` e \`msgrvsta.thm\`.

- **Ghidra 12.1.4 PUBLIC**, com JDK 21.0.13, estão disponíveis em \`E:\StormMSN-Research\tools\`.
- O projeto anterior está em \`E:\StormMSN-Research\analysis\StormMSN\`. O último log mostra que a análise de \`msnmsgr.exe\` terminou por timeout de 80 segundos, portanto não é uma análise concluída da lógica de renderização. O executável é um PE x86 de 3.878.912 bytes.
- **REA 6.8.0**, executado novamente em 2026-11-06 via \`npx rea-agents@6.8.0 doctor --provider ghidra --json\`, retornou \`healthy:true\` e todos os requisitos **do escopo Ghidra** passaram. \`environment_healthy:false\` refere-se a integrações opcionais não configuradas; não invalida o provedor selecionado.
- \`rea inspect-artifact\` verificou a integridade do executável com SHA-256 \`16660063313576d528e69bdbedb69e0c213b31cba0fae579f3e2482a00316f75\`. Essa operação classifica o artefato, mas **não** equivale à descompilação das funções de UXCore.
- A análise anterior extraiu **1.484 recursos** de \`msgsres.dll\` para \`E:\StormMSN-Research\analysis\resources\.rsrc\`.

### Estruturas UIB originais comprovadas por inspeção local

| Recurso | Papel | Identificadores lidos no recurso |
|---|---|---|
| \`4010/947\` | Tela de login | \`idEmailInput\`, \`idPasswordInput\`, \`idUserTileArea\`, \`idSignInBtnGroup\`, \`idRememberMeChk\`, \`idRememberPasswordChk\`, \`idSignInOptionsDropDown\` |
| \`4010/923\` | Lista de contatos | \`idMeArea\`, \`idMeAreaScene\`, \`idFriendlyName\`, \`idStatus\`, \`idMeAreaUserTile\`, \`UXContacts\`, \`idWhatsNewMainWindowSlideShow\`, \`idPartnerAdsToolbar\` |
| \`4010/920\` | Conversa | \`idYouAreaScene\`, \`idBuddyFriendlyName\`, \`idBuddyStatus\`, \`convinput\`, \`convinputarea\`, \`idMeUserTile\`, \`idYouUserTile\` |
| \`4010/44901\`, \`4010/44902\` | Templates de contatos | \`UXContacts\`, \`contactRow\`, \`contactLabel\`, \`ContactStatus\`, \`GroupTemplate\` |

O formato UIB é binário e possui um dicionário de identificadores; a extração de nomes não fornece automaticamente medidas, cores, fontes nem hierarquia completa. Antes de afirmar correspondência exata é preciso decodificar a estrutura e verificar a renderização.

## Medidas para o primeiro ajuste do WPF

As imagens compartilhadas pelo proprietário mostram uma janela de login com aproximadamente **291 × 690 px** e uma janela de contatos com aproximadamente **297 × 700 px**. São dimensões **de imagem**, que podem não equivaler a pixels físicos do processo devido a escala DPI, recorte da captura e moldura do Windows.

| Elemento | Prévia v0.1 | Meta preliminar v0.1.1 | Fundamento |
|---|---:|---:|---|
| Janela principal | 336 × 705 | 297 × 700, mínimo 291 × 690 | Imagens fornecidas |
| Faixa título/menu | 28 + 26 | 33 + 27 | Imagens fornecidas |
| Área superior dos contatos | 102 | 80 | Imagens fornecidas |
| Pesquisa de contatos | 48 | 48 | Alinhamento do screenshot |
| Rodapé da lista | 146 | 173 | Imagens fornecidas |
| Rodapé externo (na tela de contatos) | 35 | 0 | O rodapé de login não aparece na lista original |
| Seção superior do login | 160 | 145 | Aproxima avatar e saudação |
| Avatar de login | centralizado | com deslocamento inferior de 18 px | Enquadramento do screenshot |
| Campo de entrada login | sem margem extra | +30 px antes dos campos | Enquadramento do screenshot |

O ajuste inclui \`UseLayoutRounding=True\`, \`SnapsToDevicePixels=True\` e \`TextFormattingMode=Display\` para reduzir diferenças na rasterização do WPF.

**Esses números são hipóteses de medição de imagens, não coordenadas diretamente decodificadas do UXCore.**

## Como chegar ao resultado pixel por pixel

1. Abrir as telas **originais** em ambiente de testes com escala **100% / 96 DPI**, mesma fonte, mesmo tema e mesma resolução de captura que o novo WPF.
2. Registrar estados separados: login, autenticação em andamento com animação, contatos disponíveis/ausentes, menus e janela de conversa.
3. Decodificar os recursos UIB, mapas de estados, margens e dimensões. Usar Ghidra para investigar somente os cálculos e eventos que não estiverem declarados nos recursos.
4. Para cada estado, comparar capturas a 100% de tamanho e produzir imagens de diferença e uma lista de desvios em pixels, priorizando geometria antes de cores e sombras.
5. Repetir a comparação depois de cada build. Não inferir fidelidade somente porque o executável foi compilado.
6. Preservar o cliente original instalado e os arquivos Microsoft na pasta de pesquisa. Distribuir código e artes próprias do Storm MSN, sem empacotar DLLs e binários proprietários.

## Situação

**v0.1.1:** primeiro ajuste geométrico conforme capturas e identificadores estruturais já comprovados. **Ainda não é pixel-perfect**, não possui comparação automática por captura e não substitui o Messenger original.
