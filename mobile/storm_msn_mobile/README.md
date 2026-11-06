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
 
## Versão 0.5.0 — AdMob e perfil com conta oficial

- Entrar com nome de usuário OU e-mail + senha no mesmo campo; a API HTTPS
  de sessão valida as credenciais usando o backend original e devolve o e-mail
  para o protocolo MSNP7. A senha não é armazenada e só o ID pode ser lembrado.
- Tela Entrando... usa mascote girando central e botão Cancelar.
- Em Contatos, removida a faixa redundante do título; menu ocupa toda a
  largura; cabeçalho ajustado para evitar overflow.
- Meu avatar: tocar, escolher foto pela galeria, visualizar e remover.
  Arquivos JPEG/PNG/WebP de até 2 MB são convertidos pelo servidor em JPG
  256x256 e servidos para outros clientes. Fotos legadas do WLM não são
  importadas automaticamente; cada usuário deve atualizar o próprio perfil.
- Novidades usa o plugin nativo Google AdMob (google_mobile_ads), sem HTML,
  sem AdSense e sem WebView. Até haver App ID e unidade reais do AdMob, são
  usados APENAS IDs oficiais de anúncios de teste do Google.
- Para publicar anúncios de produção, definir STORM_ADMOB_APP_ID no build
  Android e --dart-define=STORM_ADMOB_BANNER_ID=ca-app-pub-.../... no Flutter.
  Nunca reutilizar códigos ca-pub-... do AdSense.
- Cadastro HTTPS em /cadastrar: instruções em português; /registrar protegido
  por Cloudflare Access com PIN por e-mail e validação de JWT RS256 no backend,
  vinculando o e-mail do formulário ao comprovadamente verificado.
- Android oficial usa o keystore release de v0.1.0 no host. Assinaturas
  debug de v0.2.0-v0.4.0 não são compatíveis com a release; desinstale essas
  versões de teste antes de instalar esta. APK assinado não garante que
  Play Protect deixe de mostrar alertas para instalações fora da Play Store.

### Segurança/limites
O Google Mobile Ads SDK não foi configurado com uma conta AdMob real; este
build não gera receita. Testar receita após configurar App ID, unidade de
anúncio e os formulários de consentimento apropriados na conta do Google.
O Cloudflare Access pode manter textos padrão do fornecedor em inglês mesmo
com as páginas de explicação e cadastro Storm MSN em português. O chat
desktop-Android com duas contas reais ainda exige teste manual em dispositivo.

## Versão 0.6.0 — comunicação moderna com visual Messenger 2009

### Android

- Removida a barra artificial de título da tela de entrada. Os menus clássicos
  ficam na primeira linha; a mesma faixa redundante também foi removida da
  conversa. Mantida a identidade azul/verde do Windows Live Messenger 2009.
- **Salvar senha**: somente com consentimento explícito; identificador e senha
  ficam criptografados via `flutter_secure_storage`/Android Keystore. Nunca
  são incluídos no código, nas notificações, nos logs ou nos backups Android.
  Desmarcar a opção ou fazer logout elimina os dados protegidos. O Android
  Manifest define `allowBackup=false`.
- **Conectar automaticamente**: ao reabrir, usa o identificador e a senha
  criptografados para renovar a sessão com o Storm MSN; ao recuperar o foco,
  também tenta reconectar se a rede anterior tiver caído.
- **Manter online em segundo plano**: opt-in separado e experimental com serviço
  do tipo `remoteMessaging` do Android. O serviço mantém uma notificação
  permanente; ao minimizar o app recebe a sessão MSNP7, envia avisos locais de
  conversa e registra até 40 mensagens no armazenamento criptografado. Ao
  voltar ao app, a sessão é devolvida à interface e as mensagens são recuperadas.
  O recurso exige permissão de notificações e pode ser interrompido pela gestão
  de energia do fabricante; o Android NÃO garante execução contínua.
  O serviço não inicia automaticamente após reinício do celular.
- Mensagens recebidas com socket ativo podem gerar notificação local e abrir o
  contato correto ao tocar. **FCM ainda não configurado**: para notificações
  verdadeiramente confiáveis com o processo encerrado, é necessário registrar
  o aplicativo em um projeto Firebase, conectar Firebase Cloud Messaging ao
  backend que recebe mensagens do cliente desktop e testar os estados do Android.
- **Emoticons e emojis**: seletor nativo por abas (`:)`, `:D`, `(L)` e emojis
  Unicode), com inserção na posição atual do cursor, inclusive na barra de
  digitação da conversa.
- **Mensagem de voz**: botão de microfone/Parar na barra de envio; AAC/M4A
  mono até 60 segundos, envio HTTPS autenticado, player integrado no Android.
  O MSNP7 envia um URL HTTPS opaco em texto que também pode ser aberto no PC.
  O arquivo é hospedado por no máximo 30 dias, limitado a 3 MiB; qualquer
  pessoa com o link pode abri-lo, portanto NÃO é criptografia ponta a ponta.

### Backend

- Novos endpoints `POST /api/mobile/voice` (Bearer token) e
  `GET /api/mobile/voice/{48-hex}` (capability URL). Gravações ficam em
  `/data/voice-notes` dentro do volume persistente. O servidor rejeita
  arquivos diferentes de M4A, impõe limite de tamanho, rate limit de upload,
  não executa conteúdo e remove arquivos antigos durante novos uploads.

### Inspirações e licenças

Foram avaliados os repositórios `loyldg/mytelegram` (Apache-2.0),
`telegramdesktop/tdesktop` (GPLv3 + OpenSSL exception), `rmyndharis/OpenWA`
(MIT), `karem505/whatRust` (MIT) e `amanharwara/altus` (GPLv3).
A implementação dos recursos novos é independente; nenhum código desses
repositórios foi copiado. MyTelegram gratuito não inclui as chamadas,
stickers, notificações Firebase e outros recursos anunciados apenas na edição
Pro. OpenWA é um gateway para WhatsApp, não um substituto do protocolo MSN.

### Ainda pendente

- Notificações FCM com app encerrado (exige projeto Firebase e integração no
  servidor para encaminhar mensagens desktop -> Android; o serviço Android é
  apenas um paliativo sujeito a restrições de energia).
- Chamadas de voz e vídeo nativas via WebRTC, sinalização HTTPS/WebSocket,
  TURN próprio e permissões Android, com teste entre dois celulares. Não
  substituir os botões por ações fictícias.
- Sincronização de fotos de perfil legadas e histórico de conversas do PC.
- Validação do modo em segundo plano, microfone e player num aparelho Android
  real com conta de teste; testes unitários/compilação não são garantia de
  entrega de mensagens após encerramento forçado.

### Release oficial v0.6.0 — auditoria da compilação (05/11/2026)

- Código Android: `cloud.hoststorm.storm_msn_mobile`, versionCode 6,
  versionName 0.6.0; minSdk 24 e targetSdk 36.
- Etapas: Flutter/Gradle Android compilados sem erro com NDK 28.2.13676358,
  SDK 34/35, CMake 3.22.1. Cache das ferramentas nativas preservado.
- Assinatura: release externa por `apksigner` com keystore oficial já existente
  no host. A senha não é exportada, não está no repositório e não aparece nos
  logs; a ferramenta a lê diretamente do arquivo de credenciais protegido.
- Certificado SHA-256 da release:
  `376262a5c131986323b359caddd8ba9eb68d6f3f9a1ff89635ae13aed86c25d4`.
  Idêntico à versão oficial 0.5.0, portanto atualização compatível.
- APK distribuído: `StormMSN-Mobile-v0.6.0-arm64-RELEASE.apk`,
  29.234.252 bytes,
  SHA-256 `6fbaf6882e9a31be0130fcfa9dfd85ea45a4e98c734db1291fe5490b3b2a48c4`.
- URL pública: `https://playstor.hoststorm.cloud/downloads/StormMSN-Mobile-v0.6.0-arm64-RELEASE.apk`.
  Responde HTTP 200 e o SHA-256 do arquivo integral coincide com a origem.
- Para build externo, o Gradle permite exclusivamente com variável
  `STORM_MSN_EXTERNAL_SIGNING=1` gerar APK **não assinado** e transferi-lo
  para o passo seguro de assinatura. O fluxo padrão de release continua
  exigindo as credenciais oficiais. Nunca publicar um APK não assinado.
- Testes unitários Flutter: 11 aprovados antes do build nativo. Não houve
  testes completos com dispositivo Android real nesta sessão.

## Versão 0.7.0 — avatares WLM 2009 ↔ Android + câmera

- Recomposta e publicada a camada de fotos compartilhada do Storm MSN.
  O cliente Windows Live Messenger 2009 usa StorageService SOAP
  `UserTileStatic` e identificadores MSNObject/`SHA1D`, não o endpoint
  `/api/mobile/avatar/{email}` inventado na primeira versão Android.
- Backend `avatar_shared.py` sincroniza o diretório persistente
  `/data/storage/dp` (desktop) e `/data/avatars` (Android).
  Cada upload cria JPG normalizado em 256x256 e miniatura 21x21.
  GetProfile e `/storage/usertile/{uuid}/static|small` enxergam essa foto.
- O diretório legado anterior era `storage/dp` relativo a `/app`,
  e não persistia no volume Docker. Atualizado para `/data/storage/dp`.
- Foram encontrados no cache do WLM em Nexus 31 recursos de foto:
  26 PNGs e 5 GIFs. As cópias foram validadas e armazenadas
  em `/data/legacy_tiles`, fora do APK e do repositório. A associação
  com a conta depende do hash `SHA1D` anunciado pelo cliente desktop.
  NÃO identificar imagens sem hash correspondente para evitar misturar pessoas.
- A API do Android agora consulta imagens tanto do StorageService quanto do
  cache MSNObject e usa cabeçalhos de cache para atualização.
- No Flutter, tocar no próprio avatar abre:
  **Escolher foto da galeria**, **Tirar foto com a câmera**,
  **Visualizar** e **Remover**. Imagens enviadas são limitadas a 4 MiB;
  ImagePicker redimensiona antes do envio (640 px, qualidade 80).
  Se o token expirou, o aplicativo tenta renovar uma vez apenas se
  o usuário optou por salvar a senha no Android Keystore.
- A lista atualiza as URLs dos avatares a cada 90 segundos enquanto conectada
  e ao retornar ao primeiro plano; uploads/remoções atualizam imediatamente.
- Testes reais do backend no Docker passaram: criar conta temporária,
  autenticar por username, enviar PNG via POST autorizado, recuperar JPG
  pelo endpoint Android e por UserTile desktop, recuperar thumb e deletar
  via API. A conta de teste foi eliminada.
- Notificações FCM com app totalmente encerrado ainda precisam de projeto
  Firebase e configuração do cliente/servidor. Chamadas de áudio/vídeo
  WebRTC exigem sinalização e TURN autorizados; nenhuma funcionalidade
  foi afirmada pronta ou substituída por botões falsos.
- APK release Android: `StormMSN-Mobile-v0.7.0-arm64-RELEASE.apk`,
  versão 0.7.0 (code 7), 29.234.252 bytes. SHA-256:
  `4210f1ffa7698e68dc73dfa8dca68b0a6a89aad43a77e75b01f6cccf13056294`.
  Certificado oficial SHA-256:
  `376262a5c131986323b359caddd8ba9eb68d6f3f9a1ff89635ae13aed86c25d4`,
  idêntico à release 0.6.0. Link Playstor confirmado HTTP 200 e digest
  idêntico ao arquivo original.

## Correção de mídia v0.7.1 (build 8)

Distribuição incremental sobre a release Android oficial v0.7.0 (build 7).
Usa build flags `--build-name=0.7.1 --build-number=8` para isolar
esta correção do desenvolvimento ainda não publicado da versão 0.8.0.
Manter `buildNumber > 8` na futura versão 0.8.

### Sessões de avatar e áudio
- Problema diagnosticado: a API `/api/mobile/session` criava token
  em `auth_service` **em memória**, com expiração em 12 horas.
  Um reinício do container invalidava o token, sem encerrar a sessão
  MSNP7/WebSocket. Resultado: o usuário seguia online mas não podia
  alterar avatar ou publicar áudio.
- Corrigido: emissão de credenciais de mídia em
  `login_auth_service` **persistente em SQLite**, com validade de 30 dias.
  A API `POST /api/mobile/session/refresh` gira a credencial e invalida
  o token anterior. `POST /api/mobile/session/logout` revoga a credencial.
  Tokens em memória antigos continuam aceitos temporariamente quando
  ainda existentes, mas perdem-se se já houve reinício.
- Aplicativo: ao receber 401, tenta renovar o token; se necessário, usa
  credenciais armazenadas somente se o jogador optou por salvar a senha;
  caso contrário mostra campo de confirmação de senha sem desconectar
  a conversa. Falhas de autenticação não são descritas incorretamente
  como falhas de imagem. Sair revoga o token persistente quando possível.
- Para contas que mantiveram o app 0.7.0 aberto enquanto o servidor
  reiniciou, será necessária **uma reautenticação** após atualizar.

### Gravações enviadas mas impossíveis de reproduzir
- Foi inspecionado um M4A real de 4.389 bytes: o cabeçalho
  `mdat` de 64 bits declarava 32.191 bytes, ou seja, a gravação
  estava truncada e era impossível reproduzi-la.
- Android agora aguarda a finalização integral da escrita do gravador
  (`record.stop`) e verifica os tamanhos das caixas ISO BMFF `ftyp`,
  `moov`, `mdat`, incluindo tamanhos estendidos de 64 bits.
  Se permanecer incompleto, **não envia** o link e pede nova gravação.
- O backend realiza a mesma verificação antes de aceitar uploads.
  Retorna HTTP 410 para arquivos antigos efetivamente truncados.
- Player agora baixa a mídia HTTPS para arquivo `.m4a` temporário
  e usa `just_audio.setFilePath`, evitando problemas de reprodução
  pelo URL sem extensão. Mostra erro específico para arquivo expirado,
  inexistente, incompleto e indisponibilidade de rede. Arquivos locais
  temporários são removidos ao fechar a conversa.
- Áudios já truncados não podem ser restaurados; devem ser reenviados.

### Verificações
- API real em ambiente de produção: login com conta QA temporária,
  token legível por uma nova instância do serviço SQLite, upload de foto,
  renovação, invalidação do token anterior, remoção de avatar, rejeição
  de áudio MP4 incompleto, envio e download de mídia estruturalmente
  íntegra e revogação na saída. Conta e mídias QA apagadas ao final.
- Todos os 13 testes automatizados do Flutter passaram, incluindo os
  novos cenários de tamanho estendido de M4A.
- A reprodução no aparelho Android real ainda deve ser validada após
  instalar o APK, porque os testes não substituem o hardware.

