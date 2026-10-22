# Storm MSN

Servidor MSN Messenger independente, baseado no projeto histórico [Escargot Server](https://gitlab.com/escargot-chat/server).

> **Status:** base de desenvolvimento / implantação experimental. Não é afiliado à Microsoft nem ao serviço oficial Escargot. O código original é disponibilizado sob [CC BY-NC 4.0](LICENSE), que restringe uso comercial. Consulte [UPSTREAM_README.md](UPSTREAM_README.md) e [CONTRIBUTING.md](CONTRIBUTING.md) para informações do projeto original.

## Objetivo
Permitir autenticação e conversas entre clientes MSN Messenger compatíveis em um servidor próprio, mantendo banco de usuários independente e credenciais configuráveis.

## Implantação Docker (laboratório)
1. Copie `.env.example` para `.env` e defina **senhas fortes**.
2. Configure `MSN_TARGET_HOST`, `MSN_LOGIN_HOST`, `MSN_STORAGE_HOST` com nome DNS que aponte para o servidor.
3. Execute `docker compose up -d --build`.
4. Confira `docker compose logs --tail=100 msn`.
5. Para criar contas: `docker compose exec msn python -m script.user -h` e siga o modo de uso do script legado.

Por segurança, o exemplo publica as portas MSN apenas no loopback (127.0.0.1), e o HTTP de apoio na porta local 18081. Para acesso remoto, defina regras de firewall apropriadas e publique 1863/1864 por TCP. Requisições HTTP devem passar por proxy HTTPS. **O painel sysboard (4308) não deve ser publicado.**

Clientes clássicos precisam ser configurados/patcheados para usar seu servidor, não os servidores do Escargot público. Alguns clientes e funções podem exigir domínios/rotas de autenticação e HTTPS específicos; conexão ponta a ponta **ainda não foi validada**.

Banco SQLite persistido em `../data` (fora da pasta do projeto). Não versionar credenciais ou dados privados no GitHub.

## Créditos e licença
Código original de [Escargot Chat](https://gitlab.com/escargot-chat/server), sob [Creative Commons Attribution-NonCommercial 4.0 International](LICENSE). Todos os avisos de autoria e licenciamento originais são preservados. Alterações deste repositório mantêm as restrições da licença original.

## Verificação rápida no servidor
- Status: `docker compose ps`
- Logs: `docker compose logs --tail=100 msn`
- Criar usuário (interativo): `docker compose exec msn python -m script.user usuario@exemplo.com usuario`
- Testar configuração HTTP: `curl -I http://127.0.0.1:18081/etc/MsgrConfig` (respostas variam por versão)
- A interface administrativa legada (sysboard na porta 4308) fica **somente dentro do contêiner**.

**Atenção:** clientes MSN antigos não criptografam todas as mensagens e versões antigas podem transmitir credenciais com proteção fraca. Evite reutilizar senhas de serviços atuais. É necessário configurar DNS, certificados e patch próprio do cliente antes de liberar o serviço ao público.

## Portal de contas
A aplicação inclui páginas /, /registrar, /entrar, /conta, /clientes e /api/health. Cadastro público desligado por padrão. Ative apenas com HTTPS, rate limiting na borda e moderação.


## Publicação atual e testes em 2026-10-22
- Portal HTTPS público: https://msn.hoststorm.com.br
- Cliente nativo Windows experimental: veja o artefato mais recente em https://github.com/danilostorm/msn/actions/workflows/build-client.yml
- Transporte do cliente Storm MSN: WSS https://msn.hoststorm.com.br/ws/1863 e /ws/1864 (WebSocket binário autenticado somente no protocolo MSN)
- O proxy WSS substitui o encaminhamento TCP público apenas para o cliente Storm MSN. Clientes MSN Microsoft clássicos necessitam patch/bridge e validação própria.
- E2E testado: python -m tests.e2e_client executado dentro do contêiner, com MSN_E2E_HOST=msn.hoststorm.com.br e bibliotecas websockets.
- Cadastro público DESLIGADO até verificação de e-mail/controle de abuso, termos e testes com cliente Windows; não prometer disponibilidade geral.
- Backup SQLite, métricas persistentes, limitação por conta e patch do cliente Microsoft original permanecem pendências.

## WLM 2009 (cliente Microsoft + patch Escargot)
**Este e o cliente principal do Storm MSN.** O desktop Python/Tkinter anterior
no diretorio client/ e um laboratorio legado e NAO sera divulgado ao publico.
O cliente Microsoft nao e redistribuido por este repositorio.

- Download WLM 2009 PT-BR: https://escargot.chat/download/msn/lang/pt-br/ (WLM 2009 > Download Patched)
- Configurador Switcher: https://msn.hoststorm.com.br/downloads/StormMSN-WLM2009-Configuracao.zip
- Servico TCP: im.hoststorm.com.br portas 1863 e 1864 (Oracle/Tailscale/AEROCOOL)
- Configuracoes, autenticao e contatos HTTPS: https://msn.hoststorm.com.br
- Arquivos no Windows: msnmsgr.exe-escargot.ini E wlcomm.exe-escargot.ini
- Nao modificar HOSTS ou confiar em certificados raiz autoassinados.
- A negociacao MSNP15 por rede publica nao prova login SSO, sincronizacao de
  contatos nem compatibilidade do WLM 2009 em Windows real; testes pendentes.
- Cadastro publico permanece desligado.

## Cadastro de testes
Cadastro de testes habilitado via MSN_PUBLIC_SIGNUP=1. Protecoes: CSRF, honeypot, limite por IP (3/hora) e ate 40 novas contas por 24h. Senha WLM 2009 entre 12 e 15 caracteres. Ainda nao ha confirmacao por e-mail; evitar abertura irrestrita do servico ate revisao.


## Opcional: Messenger Plus! 5.02 build 712 (Storm MSN v1.0.3)
- O WLM 2009 original continua como unico cliente principal.
- A interface do instalador tem checkbox desmarcado "Instalar também Messenger Plus! 5.02 (opcional)".
- O MsgPlus-5.02.712.7z enviado pelo usuario tem SHA-256 igual ao download oficial do Escargot: https://escargot.chat/download/msn/extras/
- A versao do Escargot usa senha 7z escargot. A extracao e feita com 7zr.exe original, obtido do site 7-zip.org sob demanda, sem embutir o instalador da Yuna no nosso EXE.
- SHA-256 7z: bc599c6640c5b9656434da810b2b7b25a7e7eaa8c4c2a7e38feb01ae485d1be8.
- SHA-256 MsgPlus-5.02.712.exe extraido: 6bb92709e160a8410cd2fb465c40ddf6fd7b9d8891473fcc69760a2caa5b4918.
- O instalador Messenger Plus! e um programa de terceiros que pode apresentar OFERTAS PATROCINADAS/ADWARE. O usuario deve revisar a tela e RECUSAR qualquer sponsor; o Storm MSN nao aprova ofertas automaticamente.
- Compativel com WLM 2009 segundo o Escargot, porem sons online podem depender da rede propria do Escargot e alguns recursos podem nao funcionar no Storm MSN.
- Configuracao do servidor Storm MSN nos dois INIs e restabelecida apos a instalacao do complemento.
- O Plus nao foi validado manualmente em uma instalacao final do WLM 2009 no Windows; o teste CI cobre integridade e extracao do pacote original.


## Storm MSN v1.0.4: Messenger Plus sem senha / Flash (22-10-2026)
- Plus! 5.02.712 ainda e um complemento opcional, nao o cliente MSN principal.
- Pacote ZIP sem senha: https://msn.hoststorm.com.br/downloads/StormMSN-MsgPlus-5.02.712.zip
- ZIP SHA256 e5d897a04a8c51156b6226608d31fbf726d7434135a46ade768ad2955f0e7038.
- Conteudo: executavel original ajustado pelo Escargot (hash 6bb92709e160a8410cd2fb465c40ddf6fd7b9d8891473fcc69760a2caa5b4918) reempacotado, sem criptografia e sem senha.
- O novo arquivo MsgPlusSetup.zip enviado pelo usuario contem um EXE de 7.980.544 bytes e SHA256 c83bdc6d48290b2ff9c54e7cb84a82404d7ee46bf1d385bfaf5804f3b8d6b55a. Seu executavel possui referencia a 'Zugo' no caminho de build original, nao identico a versao adaptada pelo Escargot. Por essa razao e para preservar o patch de som, esta variante nao foi publicada nem executada automaticamente.
- O Plus! adaptado pelo Escargot traz patches para o servidor de sons deles, NAO para o Storm MSN. Os sons remotos ainda precisam de uma integracao especifica com nosso backend. Os recursos locais podem ser testados separadamente.
- Winks do WLM 2009 dependem de Flash ActiveX. NAO instale Flash obsoleto globalmente no Windows por padrao. O tutorial do Escargot recomenda versoes antigas, mas sao riscos de seguranca. Ruffle opera como player SWF moderno mas nao oferece um ActiveX drop-in para o WLM. Isolamento ou adaptacao independente seriam o caminho futuro.

## Storm MSN 1.0.5 — Messenger Plus do usuario e investigacao Flash
- Instalador reconhece MsgPlusSetup.zip ao lado do StormMSN-Setup.exe e usa o executavel enviado pelo usuario, verificando SHA256 de ambos.
- ZIP usuario SHA256 5355326b50e7b22de8b3fa3493f1c186b800e2e357d679e2cdf52c2bff0bfb70.
- EXE usuario SHA256 c83bdc6d48290b2ff9c54e7cb84a82404d7ee46bf1d385bfaf5804f3b8d6b55a.
- Execucao automatica no fluxo do instalador quando opcao Plus selecionada ou via --with-plus, mantendo as telas de consentimento originais. Sem alterar os servidores MSN.
- Sem MsgPlusSetup.zip, usa o arquivo sem senha baseado na distribuicao Escargot.
- Analise estatica do WLM 2009: executavel msnmsgrexe extraido de MsgrCore.cab inclui referencias MinFlashPlayer, DDPFlashNotInstalled, DDPFlashPlayer, Macromedia e http://www.macromedia.com/go/getflashplayer/.
- Os winks WLM 2009 sao pacotes .mct (CABs) contendo .swf e assets. Exemplos: bola.mct, bow.mct, dancing_pig.mct.
- Escargot documenta Flash ActiveX 7.0-10.3 e isolamento COM como alternativa; nao foi encontrado Flash ActiveX embutido. Flash antigo nao incluido no Storm MSN.
