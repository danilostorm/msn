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
