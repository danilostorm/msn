# Storm MSN Desktop

Cliente independente em Python + Tkinter (sem binários proprietários da Microsoft).

- MSNP7: login com MD5 legado, status, contatos, conversa de texto.
- Execute localmente: python client/storm_msn.py
- Para Windows: GitHub Actions gera um arquivo Storm-MSN.exe usando PyInstaller.
- Servidor inicial 127.0.0.1; altere para o endereço público quando habilitado.
- Por segurança, nunca reutilize senha moderna no cliente MSNP7.
- Não há criptografia de ponta a ponta, suporte de mídia ou webcam nesta versão.
- Esta versão é experimental; os fluxos de chat precisam ser testados no Windows.

## Conectar remotamente pelo WSS
No cliente Storm MSN Desktop, use o servidor msn.hoststorm.com.br. O cliente utiliza conexões WSS criptografadas para o serviço MSNP7 do AEROCOOL, sem exigir encaminhamento de portas nem proxy pago. A senha de cliente antigo continua baseada em MD5 no servidor, portanto use apenas senha exclusiva deste projeto. Para testar localmente sem WSS, use 127.0.0.1.
Dependência Python: pip install websockets


### Build Windows
Acesse https://github.com/danilostorm/msn/actions/workflows/build-client.yml, abra a última execução com sucesso e baixe o artefato Storm-MSN-Windows. O executável não foi testado manualmente em um Windows real; trata-se de uma versão experimental.

### Segurança
- O tráfego entre o cliente próprio e o domínio é protegido por WSS, mas o servidor usa MD5 legado; não utilize a mesma senha de outros serviços.
- O modo TCP puro destina-se exclusivamente a laboratório local.
- Não existe integração com contas Microsoft nem com o Escargot público.
