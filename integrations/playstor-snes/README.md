# Storm MSN × PlayStor — catálogo SNES

**Primeiro teste implantado em 05/11/2026.**

O menu de jogos do **Windows Live Messenger 2009** aponta para o catálogo SNES do PlayStor, preservando o login e o failover do Storm MSN.

## Endereços

- Catálogo público: `https://msn.hoststorm.com.br/AppDirectory/Directory.aspx`
- Versão do catálogo: `https://msn.hoststorm.com.br/AppDirectory/GetAppdirVersion.aspx`
- Metadados experimentais: `https://msn.hoststorm.com.br/AppDirectory/AppDirectory.asmx`
- Catálogo de origem: `https://playstor.hoststorm.cloud/api/games?system=snes`
- Jogos individuais: `https://playstor.hoststorm.cloud/?game=<ID>`, com login no PlayStor.

Foram identificados **230 registros SNES** em 05/11/2026, consultados em tempo real. O serviço aceita pesquisa, apresenta capas públicas e pagina 24 jogos por página. **Não serve ROMs nem transmite credenciais do PlayStor.** O PlayStor protege as ROMs com login próprio.

## Integração técnica em produção

A Oracle, nó de ingresso do MSN, executa:

- `playstor-snes.js` em `127.0.0.1:18590` (systemd `storm-msn-snes-catalog.service`). Atualiza o catálogo consultando o endpoint público do PlayStor, com cache de 3 minutos e último catálogo válido até 1 hora em caso de falha.
- `playstor-snes-ts-proxy.js` em `100.114.49.54:18592`, restrito às origens Tailscale AEROCOOL `100.99.136.79` e SuperFrame `100.107.117.74` (systemd `storm-msn-snes-ts-proxy.service`).

No túnel Cloudflare `storm-msn-web` (`4bd8e615-6990-4758-95c1-14979d21df2b`), foi inserida uma regra **antes** da rota geral:

```json
{
  "hostname": "msn.hoststorm.com.br",
  "path": "^/AppDirectory/.*",
  "service": "http://100.114.49.54:18592"
}
```

As demais rotas, especialmente `msn.hoststorm.com.br` geral e `admin-stormpt.hoststorm.cloud`, permanecem inalteradas. Backup privado da configuração anterior fica na Oracle em `/root/storm-msn-ha/cloudflare-config-before-snes-20261105.json`.

O arquivo `front/msn/tmpl/MsgrConfig.wlm.14.xml` agora contém `GamesBrowserURL` apontando ao catálogo. A versão atual do arquivo foi copiada para o container `storm-msn` no AEROCOOL **sem restart** e também ao container de reserva no SuperFrame, que permanece desligado até promoção. Recriações de container precisam reconstruir a imagem a partir desta fonte atualizada; editar a fonte no host sem rebuild não atualiza uma imagem antiga.

## Testes

```bash
node integrations/playstor-snes/test-catalog.js
curl -fsS https://msn.hoststorm.com.br/AppDirectory/Directory.aspx
curl -fsS 'https://msn.hoststorm.com.br/Config/MsgrConfig.asmx?ver=14.0.8117' | grep GamesBrowserURL
```

Foram verificados HTTP 200, catálogo de 230 jogos, links de jogo, busca, sanitização HTML/XML, configuração WLM 2009 e continuidade do MSN (container e monitor da Oracle saudáveis).

**Compatibilidade:** o catálogo HTML foi feito para o navegador antigo incorporado ao WLM 2009, mas o comportamento do botão Jogos **ainda depende de validação com o cliente real**. A emulação SNES é moderna (WebAssembly/JavaScript), portanto o link abre o PlayStor em um navegador atual; não roda dentro do motor IE legado. Não há sincronização multiplayer, convite nativo, controle remoto compartilhado nem execução de ROM sem login.

Os endpoints SOAP `AppDirectory.asmx` e de versão são **experimentais** e não alegam implementar integralmente o SDK de atividades do MSN; podem precisar de ajustes conforme capturas reais do WLM 2009.

## Segurança e direitos

Não publicar ROMs no GitHub, não ignorar autenticação do PlayStor e não incorporar Flash/ActiveX antigos globalmente no Windows. Verificar os direitos de distribuição e execução dos jogos disponíveis na biblioteca.

Se o menu não aparecer no WLM, sair e entrar novamente, testar em nova conversa e obter diagnóstico de quais endpoints o cliente realmente solicita. Não alterar os serviços de login nem desligar os conectores Cloudflare para esse teste.
