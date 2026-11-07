# Storm MSN - fidelidade total da aparencia original do WLM 2009

## Regra obrigatoria

O cliente Windows principal e o **Windows Live Messenger 2009 PT-BR original**, versao
`14.0.8117.0416`. **Nao reconstruir a interface em WPF, Flutter, Electron, Rust,
WinForms, HTML ou qualquer outro toolkit**. Nao aceitar representacoes "parecidas".
Nenhum novo icone, cor, fundo, botao, menu, transicao ou mudanca de geometria na UI.

As telas devem continuar sendo desenhadas pelos proprios componentes instalados
do WLM 2009. O servidor Storm MSN deve se adaptar ao protocolo/servicos do cliente,
nao o cliente se adaptar ao servidor. Se uma funcionalidade nova exigir mudanca
visual, ela fica desativada ou e disponibilizada como complemento separado,
sem substituir ou personalizar as telas do WLM.

A branch antiga `feat/stormmsn-windows-parallel` e apenas um experimento de interface
que **nao atende ao objetivo**. Nao distribuir como cliente principal.

## Arquivos protegidos e provas

Os arquivos `msnmsgr.exe`, `msgsres.dll`, `uxcore.dll`, `msgrvsta.thm`,
`msgslang.*.dll` e outros recursos do Windows Live devem permanecer preservados,
exceto patches de compatibilidade estritamente necessarios, aprovados e auditados.
O Switcher Escargot pode alterar imports de executaveis para permitir outro
servidor; isso significa que os EXEs **patcheados nao sao necessariamente identicos
byte a byte** aos originais. Os recursos visuais nao devem ser alterados.

`Verificar-Integridade-Original.ps1` inventaria arquivos protegidos sob
`Windows Live` (binarios, recursos e tipos de midia), sem mudar nenhum.
A baseline registra o **estado local presente**, e so prova que o estado nao
mudou **entre a captura e a verificacao**. Uma baseline capturada depois de um patch
nao garante autenticidade Microsoft nem igualdade visual com o original.

Executar no PowerShell, na pasta `wlm2009`:

```powershell
# Gerar uma unica baseline depois de confirmar que instalacao/patch sao legitimos.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Verificar-Integridade-Original.ps1 -Mode Capture

# Executar antes e depois de integrar configuracoes de rede/backend.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Verificar-Integridade-Original.ps1 -Mode Verify
```

Se detectar arquivo novo, alterado ou excluido, encerra com codigo 2.
Scripts do Switcher que alteram somente os `.ini` sao deliberadamente excluidos
do conjunto protegido. O script nao solicita senha nem inicia o Messenger.
Se for substituir a baseline, nao usar `-Force` automaticamente: primeiro
revisar a mudanca real e fazer backup da prova anterior.

## Evidencias da integracao (2026-11-06)

Teste somente de negociacao, usando uma identidade sintetica, via Oracle para
`im.hoststorm.com.br:1863`:

- `VER 1 MSNP18 MSNP17 MSNP16 MSNP15 CVR0` recebeu `VER 1 MSNP18`.
- `CVR` com cliente `MSNMSGR 14.0.8117.0416` recebeu CVR com a mesma versao.
- `USR 3 SSO I synthetic@example.invalid` recebeu desafio `USR 3 SSO S` e `GCF`.
- TCP 1863/1864 e portal/configuracao HTTPS responderam no AEROCOOL/Oracle.

**Nao comprovado:** login SSO completo com cliente real, sincronizacao
`wlcomm.exe`, lista de contatos, multimidia e servicos secundarios.
Sucesso no handshake nao autoriza chamar o sistema de 100% funcional.

## Validacao definitiva necessaria no Nexus

1. Reconectar o Nexus: em 2026-11-06, o acesso SSH ao Tailscale
   `100.75.191.57` falhou e o AEROCOOL indicou o dispositivo offline.
2. Estudar a instalacao de referencia somente em leitura:
   `E:\StormMSN-Research\original`. Ghidra e REA devem ajudar a localizar
   classes, recursos e fluxos nativos; **nao usar seus resultados para
   redesenhar a UI**.
3. Registrar versoes, hashes e estado do cliente instalado. Confrontar
   recursos originais com os da instalacao de teste e registrar diferencas
   justificadas de patch.
4. Abrir e testar o WLM 2009 original com conta de teste Storm MSN.
   Registrar login, contatos, conversa, estados, menus e janelas originais.
5. Realizar capturas no mesmo Windows, tema e DPI para validar casos de
   runtime; a garantia visual principal vem do **motor e recursos originais**.
6. Integrar chamadas, fotos, voz, jogos e outros servicos prioritariamente
   por protocolos/endpoints; quando a tela original nao conseguir renderizar
   a nova funcao sem alteracao, manter opcional externo em vez de substituir
   elementos visuais.

## Fonte do patch oficial

Documentacao Escargot, que descreve como o Switcher redireciona requisicoes
de clientes originais e a exigencia de patch para `msnmsgr.exe` e `wlcomm.exe`:

- https://escargot.chat/download/switcher/
- https://www.escargot.chat/connect/guides/
- https://www.escargot.chat/download/msn/lang/pt-br/

Nao comitar/redistribuir executaveis, DLLs, temas ou artes proprietarias da Microsoft.

## Estado de validacao

O inventario de integridade passou em um Windows GitHub Actions usando
**arquivos sinteticos**, com testes de captura, verificação, `.ini` permitido,
recurso adulterado, removido e adicionado. O script nao foi executado no Nexus
porque o computador estava offline.

## Iniciador nativo testado no Nexus (06/11/2026)

Abra **`Abrir-StormMSN-Original.cmd`** pelo desktop do Windows.
O script `Abrir-StormMSN-Original.ps1` verifica somente a integridade
de presenca dos componentes e as opcoes do Switcher. Ele chama o
`msnmsgr.exe` original, sem criar nenhuma janela de interface propria.

Para fazer apenas a validacao, sem abrir a aplicacao:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Abrir-StormMSN-Original.ps1 -CheckOnly
```

**Evidencia no Nexus:** classe de janela **`MSBLWindowClass`**,
310 × 700 pixels a 96 DPI, criada pelo processo original.
Foram encontrados `UXCore.dll`, `msgsres.dll` e `escargot.dll`
carregados pelo WLM, alem dos recursos UIB de login, contatos e conversa.
A interface original foi aberta, mas o login e as demais funcionalidades
**ainda nao foram testados ponta a ponta**.

A tentativa de abrir o cliente com tarefa elevada (`RunLevel Highest`)
coincidiu com um crash em `wldlog.dll`; a execucao interativa
`RunLevel Limited` abriu a janela sem repetir a falha. Nao sabemos
a causa precisa do crash. Prefira abrir normalmente, sem
`Executar como administrador`. Nao altere a DLL sem diagnostico.

Relatorio: [Janela original no Nexus](lab/NEXUS-REAL-WINDOW-2026-11-06.md).
