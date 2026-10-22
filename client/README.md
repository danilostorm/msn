# Storm MSN Desktop

Cliente independente em Python + Tkinter (sem binários proprietários da Microsoft).

- MSNP7: login com MD5 legado, status, contatos, conversa de texto.
- Execute localmente: python client/storm_msn.py
- Para Windows: GitHub Actions gera um arquivo Storm-MSN.exe usando PyInstaller.
- Servidor inicial 127.0.0.1; altere para o endereço público quando habilitado.
- Por segurança, nunca reutilize senha moderna no cliente MSNP7.
- Não há criptografia de ponta a ponta, suporte de mídia ou webcam nesta versão.
- Esta versão é experimental; os fluxos de chat precisam ser testados no Windows.
