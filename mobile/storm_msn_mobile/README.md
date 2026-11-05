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

