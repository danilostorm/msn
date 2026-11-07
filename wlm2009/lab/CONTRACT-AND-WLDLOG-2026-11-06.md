# Storm MSN / WLM 2009 original — auditoria de estabilidade e contratos

**Data:** 06/11/2026. **Branch:** `feat/wlm2009-original-fidelity`.
**Principio:** usar o proprio Windows Live Messenger 2009 PT-BR
`14.0.8117.0416`; nada de recriar a interface em WPF ou mudar
DLLs, temas, fontes, botoes ou recursos visuais.

## Estado do cliente Nexus

A instalacao em `C:\Program Files (x86)\Windows Live`
continua com os **55 arquivos protegidos identicos** ao baseline
`E:\StormMSN-Research\analysis\integrity\WLM2009-original-install-baseline.json`.

No momento da verificacao:
- `msnmsgr.exe` e `wlcomm.exe` ativos na sessao interativa 1.
- `msnmsgr.exe` com TCP estabelecido com `im.hoststorm.com.br:1863`.
- O cliente original usa `UXCore.dll`, `msgsres.dll`, `msgslang`,
  `msidcrl40.dll` e o `escargot.dll` do Switcher.
- A janela grafica `MSBLWindowClass` foi verificada em teste anterior:
  310x700 pixels, 96 DPI, renderizada pelo executavel original.
- **Nenhum arquivo do cliente original alterado ou substituido.**

## Falha Windows: wldlog.dll

O registro Windows Application Error / evento 1000 mostrou o
**mesmo deslocamento** de falha duas vezes:

| Hora local no Nexus | Processo | Modulo | Codigo | RVA |
|---|---|---|---|---|
| 21:19:22 | msnmsgr.exe | wldlog.dll | c0000005 | 00001933 |
| 21:50:57 | msnmsgr.exe | wldlog.dll | c0000005 | 00001933 |

A `wldlog.dll` original da pasta Messenger tem assinatura Microsoft
valida, versao `14.0.8117.0416` e SHA-256
`eccdfe62f8d5ee7b9d77297287631df31768fe0d7ab3c7e81afe1cd3a008c7ca`.

O Ghidra 12.1.4 foi executado sobre uma COPIA da DLL, em projeto
isolado, com `DecompileWldlogFault.java`:
- Funcao em RVA `0x1923`; erro observado em `0x1933`.
- A funcao percorre uma lista ligada obtida de um campo interno,
  comparando cadeias com `lstrcmpiA`.
- A leitura em `MOV EAX, [ESI]` falha quando o ponteiro de lista
  e invalido. A rotina decompilada trata lista vazia, mas uma lista
  corrompida ainda pode disparar uma excecao.
- Oito referencias de chamadas identificadas para a funcao.
- **Isso nao prova quem corrompeu o ponteiro**. Nao e evidência
  conclusiva contra Windows 11, Messenger Plus!, Switcher ou Storm MSN.

**Conduta:** nao substituir, corrigir por hex-editor nem renomear
`wldlog.dll` sem reproduzir e isolar a causa. Qualquer captura de dump
de memoria devera ser deliberada e protegida: pode conter credenciais
e conversas. Nao foi habilitada.

## Contrato de protocolo e servicos (rede real, sem login)

O script `wlm2009/lab/probe_wlm2009_contract.py` foi executado a
partir da Oracle contra a infraestrutura publica Storm MSN, sem
contas, passwords, tokens persistidos ou alteracoes de dados:

| Etapa | Resultado |
|---|---|
| `VER 100` / MSNP18 | OK |
| `CVR 101` / `14.0.8117.0416` | OK |
| `USR 102 SSO I` / desafio `SSO S` | OK (somente fase inicial) |
| Portal `/api/health` | HTTP 200 |
| `/etc/MsgrConfig` | HTTP 200 |
| `/RST.srf` com XML sem credenciais | XML de rejeicao valido |
| `/RST2.srf` com XML sem credenciais | XML de rejeicao valido |
| Rotas SOAP de contatos, compartilhamento e armazenamento | Presentes |

O cliente **nao** foi autenticado por este probe: o script
encerra antes de enviar respostas SSO. A verificacao das rotas SOAP
nao demonstra sincronizacao de contatos com usuario autenticado.

O probe e intencionalmente opt-in via `--live`; a resposta
desafiadora SSO nao e registrada. Em Oracle:

```bash
python3 probe_wlm2009_contract.py --live \
  --tcp-host im.hoststorm.com.br \
  --https-host msn.hoststorm.com.br
```

## Testes automatizados de regressao

O workflow `.github/workflows/wlm2009-original-fidelity.yml`
executa no Windows:
1. Inventario de integridade em arquivos sinteticos (permitindo apenas
   mudancas em INIs do Switcher).
2. Testes offline do probe: fragmentacao TCP, resposta MSNP incorreta,
   rejeicao XML, rota SOAP ausente e autorizacao explicita `--live`.

Uma falha inicial do teste de TCP fragmentado revelou um bug **no
probe novo**, corrigido no commit `eb2b0ad5633c37bdaa085bd3a673912a086047e4`.
O workflow passou apos a correção. O probe real foi executado
novamente na Oracle e retornou `ok=true`.

## O que nao foi concluido

- Login SSO de verdade com conta de teste descartavel, sincronizacao
  `wlcomm.exe`, lista de contatos e conversa ponta a ponta.
- Isolamento da causa raiz do `wldlog.dll` em ambiente de teste.
- Voz, webcam, chamada, jogos e compartilhamento funcionando no cliente.
- Verificacao pixel a pixel para todos os estados dinamicos. **O cliente
  atual e o original, nao uma reimplementacao grafica.**

**Produção:** nenhum contêiner reiniciado, nenhum banco alterado,
nenhum usuario criado e nenhuma DLL/tema Microsoft modificada.
