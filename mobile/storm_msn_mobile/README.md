# Storm MSN Mobile — Android

Aplicativo Android original em Flutter, inspirado visualmente no Windows Live Messenger 2009 (WLM 2009), adaptável a telefones e tablets. Não distribui componentes proprietários Microsoft.

## Versão 0.1.0 (prévia)

Funcionalidades implementadas no código: interface clássica azul, login MSNP7 por WSS criptografado, lista/pesquisa de contatos, status, bate-papo, adição de contatos, emoticons, catálogo SNES PlayStor via navegador externo e layout responsivo de uma coluna/duas colunas.

Limitações: a reprodução não é 100% pixel-perfect; webcam, chamadas de voz/vídeo, compartilhamento de arquivos, jogos dentro do cliente antigo, multiplayer sincronizado, notificações push e sessão em segundo plano estão pendentes. O app não é uma emulação do executável Microsoft Windows Live Messenger. Login e conversas devem ser confirmados em um Android real com contas existentes do Storm MSN.

## Endereços usados

- wss://msn.hoststorm.com.br/ws/1863 — MSNP7 autenticação, status e lista.
- wss://msn.hoststorm.com.br/ws/1864 — MSNP7 switchboards para conversas.
- https://msn.hoststorm.com.br/AppDirectory/Directory.aspx — catálogo SNES externo.

Não armazena senhas. Usa autenticação MD5 legada encapsulada em WSS. Não reutilize senhas de outros serviços.

## Compilar

Requer Flutter 3.44+ e Android SDK. Execute no diretório do projeto:

    flutter pub get
    flutter test
    flutter build apk --debug --target-platform android-arm64

Para distribuição oficial defina variáveis de ambiente STORM_MSN_RELEASE_KEYSTORE (caminho do P12) e STORM_MSN_RELEASE_PASSWORD; alias da chave stormmsn. Nunca faça commit da chave ou senha.

    flutter build apk --release --target-platform android-arm64 --build-name=0.1.0 --build-number=1

O APK oficial deve ser assinado com a mesma chave permanente para permitir futuras atualizações. A chave é armazenada no AEROCOOL e copiada fora do SSD cache. No repositório GitHub publicar somente fontes e instruções; nunca arquivos de contas, dados SQLite ou credenciais.

## Testes

1. Instalar o APK ARM64 em aparelho Android.
2. Entrar com conta cadastrada do Storm MSN.
3. Verificar lista, status e adição de contatos.
4. Entrar com uma segunda conta no Windows Live Messenger 2009 e testar chat de ida/volta.
5. Tocar em Jogos, confirmar abertura do catálogo PlayStor em navegador moderno.

O protocolo atual pressupõe sessão em primeiro plano; se houver failover e perder a conexão, faça login novamente.

As cores, ilustrações e ícones foram criados para o Storm MSN. O projeto é independente da Microsoft.


## Atualização 0.3.0 — estudo do WLM 2009 no Nexus

A pesquisa dos recursos do `msgsres.dll` identificou os layouts binários originais da interface: `4010/947` (login), `4010/923` (contatos), `4010/920` (conversa) e `4010/44901`/`44902` (linhas de contatos). A análise foi feita no Nexus usando Ghidra 12.1.4 e REA 6.8.0; os componentes Microsoft não são distribuídos no APK.

Principais mudanças de interface: faixa Aero e título do WLM, avatar à esquerda dos campos em celulares compatíveis, ações Entrar/Cancelar, seleção de presença, opção de lembrar apenas o ID, barra e menus clássicos de contatos e ações com texto na conversa. Recuperação automática de senha ainda não existe, portanto o botão explica a limitação em vez de redirecionar para outro serviço.

Correções MSNP7: interpretação adequada da lista `LST FL` sem confundir os contadores e sem inserir permissões `AL`/`BL` como contatos; presença `NLN`/`ILN` e erros numéricos do servidor. Os testes usam um WebSocket local com conta de demonstração e cobrem login, sincronização, presença, contato e abertura da conversa. O teste opcional `live_wss_test.dart` confirma apenas a resposta a login inválido no WSS público.

**Validação pendente:** login com uma conta válida e chat bidirecional num aparelho Android físico. Chamadas de voz/vídeo, envio de arquivos, multiplayer e notificações em segundo plano não foram ativados.

O APK `0.3.0-TESTE` é um build de desenvolvimento e não compartilha necessariamente a assinatura da versão oficial. Ao alternar entre assinaturas, desinstale o aplicativo antigo antes de instalar o novo.

## Atualização 0.4.0 — reconstrução guiada por capturas do WLM 2009

Usa as capturas da tela de login e dos contatos do desktop como referência visual para a versão Android. Entrada com barra de título e menus, faixa turquesa/verde recriada em Flutter, avatar centrado, saudação original, campos abaixo, seleção de presença, botão Entrar e links inferiores. Durante a conexão o mascote azul/verde gira. A arte é independente e não inclui recursos binários da Microsoft. O avatar original do usuário ainda não é sincronizado automaticamente.

Contatos: cabeçalho compacto com gramado, menu clássico e botões conectados, pesquisa, seção de favoritos (organização local da sessão por toque prolongado), grupos reais obtidos de LSG/LST no MSNP7, seções Disponível/Offline e painel de Novidades. A lista agora apresenta aviso destacado e contador de mensagens não lidas, tocáveis para abrir a conversa. Contatos favoritos ainda não são persistidos entre sessões.

Correções: diálogos e avisos do Flutter agora utilizam contexto subordinado ao MaterialApp (anteriormente abriam com erro No MaterialLocalizations found); adição aguarda confirmação real do servidor antes de avisar sucesso. Interpretação de eventos RNG de convite, ANS de resposta, mensagem MSG multipartes, aviso de nova mensagem e sincronização LSG de grupos testados com servidor MSNP7/WebSocket de laboratório.

Limitações: a validação concluída foi com servidor simulado. Ainda é necessário testar com duas contas reais, desktop Windows Live Messenger ↔ Android, para confirmar compatibilidade ponta a ponta com o servidor de produção. Aplicativo em segundo plano, notificações push, áudio/vídeo, avatar remoto e fidelidade visual pixel a pixel ainda são trabalhos pendentes. Nunca compartilhe senhas de usuários nos testes.
