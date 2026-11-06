# Storm MSN Classic para Windows — prévia 0.1

Cliente **paralelo** em C# / WPF e .NET 8, pensado para preservar a aparência do Windows Live Messenger 2009 enquanto novas funções de mensagens são desenvolvidas. Não altera nem substitui o Windows Live Messenger instalado. A versão é preliminar e não tem promessa de fidelidade pixel a pixel.

## Como executar

No Nexus há um SDK .NET 8 instalado localmente em \`E:\StormMSN-WindowsParallel\tools\dotnet\`. Para testar em qualquer Windows x64 sem instalar o SDK, use o arquivo ZIP produzido no GitHub Actions, extraia a pasta inteira e execute \`StormMSN.Classic.exe\`.

A aplicação oferece botão **Prévia visual sem conectar** para examinar os layouts de contatos e conversas sem credenciais, com dados fictícios claramente marcados.

## Já implementado no código

- Tela de login, menu Arquivo/Contatos/Ações/Ferramentas/Ajuda, janela com composição clássica e animação de entrada.
- Login real: API HTTPS \`/api/mobile/session\` para validar usuário/e-mail e senha e converter identificador; conexão ao protocolo **MSNP7** via WSS (\`/ws/1863\`) e switchboard de conversas via WSS (\`/ws/1864\`).
- Autenticação MD5 legado, sincronização FL de contatos, estados, notificações de mensagens, envio/recebimento de texto, adicionar contatos.
- Miniaturas de perfis consultadas na API de avatar do Storm MSN.
- Janela de conversa separada; envio de imagem e arquivo via API autenticada; interpretação de imagens, arquivos e mensagens de voz já enviadas pelo aplicativo Android.
- Responder, copiar e apagar somente nesta janela, sem alegar apagamento remoto.
- Senha **não é salva**; apenas o e-mail pode ser lembrado localmente.

## Ainda não implementado / sem validação física

- Não existe paridade 100% pixel a pixel com o binário original. O primeiro alvo é experimentar o visual e a arquitetura WPF sem prejudicar a produção.
- A gravação de voz e chamadas de áudio/vídeo no Windows não estão prontas. A recepção de áudio pode depender dos codecs do Windows.
- Arquivos do aplicativo Android são links de capacidade HTTPS, não são criptografados ponta a ponta.
- Apagar para todos, edição sincronizada, notificações push, histórico persistente e troca automática de sessão entre PC/celular exigem API de mensagens nova e validação.
- Este código ainda deve ser validado no Windows desktop com contas próprias antes de distribuir a usuários.

## Segurança e isolamento

Este cliente não injeta código em \`msnmsgr.exe\` ou \`msgsres.dll\`, não modifica o cliente original, não substitui arquivos de registro do Windows Live Messenger e não altera as contas nem dados dos outros serviços. Compilação na pasta \`windows/StormMSN.Classic\`, com fluxo GitHub Actions próprio.
