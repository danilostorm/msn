# Nexus — interface nativa Windows Live Messenger 2009: testes da sessao grafica

Data: 2026-11-06. Host: `NEXUSLITE-PC`.
Escopo: **exclusivamente o WLM 2009 original**, versionado como
`14.0.8117.0416`. Nenhum redesenho WPF. Nao copia binarios da Microsoft
para o GitHub. Nenhuma credencial ou conversa foi coletada.

## Diagnostico das janelas (sessao 1)

- A sessao SSH do Windows era a **sessao 0**, enquanto o WLM estava na
  **sessao interativa 1**. Logo, `MainWindowHandle=0` visto no SSH
  **nao provava que o WLM nao tinha interface**.
- O WLM iniciou em `/background`, criando janelas auxiliares, sem
  mostrar o painel de login/contatos.
- Um processo do usuario executou `Inspect-NativeWindows.ps1` na
  sessao 1 por tarefa agendada **temporaria**, removida logo apos a medicao.
  A ferramenta utiliza Win32 `EnumWindows` e nao captura pixel ou texto.
- A abertura do executavel original, sem `/background`, na sessao
  interativa com `-RunLevel Limited`, resultou em:

  - Classe Windows: **`MSBLWindowClass`**.
  - Tamanho real: **310 × 700 pixels**, DPI **96**.
  - Janela visivel: **true**.
  - Execucao com arquivo original `msnmsgr.exe`, e nao com WPF.
  - Nao houve novo evento de crash nesse teste.
  - Verificacao final apos lancador: janela `MSBLWindowClass`
    permanece visivel (310 × 700, 96 DPI, X=150, Y=210).

- A inspeção por UI Automation encontrou **5 nós** de acessibilidade,
  todos identificados como `ControlType.Pane`, e nenhuma
  arvore convencional de botoes/caixas de texto. Isso e consistente
  com a renderizacao personalizada do WLM, embora nao revele o
  algoritmo exato dos pixels nem prove que todos os estados estao corretos.
- O processo original de 32 bits apresentava **196 modulos carregados**.
  `UXCore.dll`, `msgsres.dll`, `msgslang.14.0.8117.0416.dll`,
  `msidcrl40.dll`, `wldlog.dll` e `escargot.dll` foram observados.
  `wlcomm.exe` carregava `escargot.dll` e `wldlog.dll` de sua pasta.
- A auditoria final confirmou **55 hashes protegidos inalterados**.

## Crash anterior: nao confundir com problema de layout

Uma tentativa de abrir o executavel via tarefa interativa com
`RunLevel Highest` coincidiu com um evento Windows Application Error
(ID 1000) em `msnmsgr.exe`, com:

- Modulo: **`wldlog.dll`**, versão `14.0.8117.0416`.
- Excecao: **`0xc0000005`**.
- RVA: **`0x1933`**.
- A DLL instalada da pasta Messenger tem assinatura Microsoft **Valid**
  e SHA-256 `eccdfe62f8d5ee7b9d77297287631df31768fe0d7ab3c7e81afe1cd3a008c7ca`.
- O Ghidra 12.1.4 analisou uma **copia isolada da DLL** em
  `E:\StormMSN-Research\analysis\integrity`,
  nunca modificando a instalacao.
- Instrucao em `RVA 0x1933`: `MOV EAX,dword ptr [ESI]`.
  A funcao comeca em `RVA 0x1923`.
- A instrucao le uma memoria apontada por ESI: e coerente com violacao de acesso,
  mas a causa raiz, a origem do ponteiro invalido e a relacao causal com elevacao
  de privilegios **nao foram determinadas**.
- O WLM foi restaurado usando `/background` com `RunLevel Limited`.
  O processo voltou a estabelecer conexao TCP 1863 com Storm MSN.

**Nao renomear, substituir ou aplicar patches em wldlog.dll por tentativa e erro.**

## Iniciador nativo sem redesenho

`wlm2009/Abrir-StormMSN-Original.ps1` e
`wlm2009/Abrir-StormMSN-Original.cmd`.

O iniciador verifica, **sem escrita**:
- executaveis e arquivos visuais originais obrigatorios;
- versao 14.0.8117.0416;
- Switcher em Messenger e Contacts com
  `server=im.hoststorm.com.br` e
  `configserver=msn.hoststorm.com.br`.

A opcao `-CheckOnly` valida e nao abre processos.
Sem a opcao, chama **somente o cliente Microsoft original**.
Recusa iniciar GUI na sessao SSH 0, e avisa sobre privilegios
administrativos. Não instala, atualiza, empacota, substitui
ou redesenha a interface.

No Nexus, o `-CheckOnly` retornou 0. O iniciador executado na
sessao 1 via tarefa temporaria retornou 0, sem novas falhas.
Apos alguns segundos, o WLM retornou a uma so instancia
`msnmsgr.exe` mais `wlcomm.exe`, com conexao TCP 1863,
janela original visivel e **55 hashes de integridade preservados**.

## Pontos ainda nao validados

- Autenticacao completa com conta de teste no cliente nativo,
  lista de contatos, conversa, video, voz, compartilhamento, jogos
  e transicoes de estado.
- Comparacao dinamica de cada estado visual; o uso dos
  binarios e recursos nativos reduz o risco de divergencia,
  mas ambientes diferentes (Windows, tema, fontes, DPI)
  podem alterar a renderizacao.
- Nao foram executados logins de contas reais, lidas senhas,
  capturadas conversas nem produzida distribuicao Microsoft.

## Scripts incluidos

- `Inspect-NativeWindows.ps1`: janelas reais, classes, geometrias e DPI.
- `Inspect-NativeControls.ps1`: arvores UI Automation sem ler texto.
- `Inspect-LoadedModules.ps1`: hash de modulos DLL no PowerShell x86.
- `InspectWldlogCrash.java`: leitura de DLL copiada pelo Ghidra.
- `Test-OriginalWindowLaunch.ps1`: experimento temporario com
  recuperacao automatica em caso de encerramento.

Todos os scripts de laboratorio foram executados sobre a copia de
pesquisa em `E:\StormMSN-Research\analysis\integrity`,
sem inserir ou modificar arquivos na instalacao original.
