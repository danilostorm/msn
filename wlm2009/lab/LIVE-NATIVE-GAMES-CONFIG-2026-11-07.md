# Storm MSN 2009 — publicação controlada da configuração nativa de Jogos

Data: 7 de novembro de 2026. Alteração originada na branch feat/wlm2009-original-fidelity.

## Motivo

O código original de Windows Live Messenger 2009 14.0.8117.0416 contém a referência LocalizedConfig/AppDirConfig/GamesBrowserURL, mas o XML público anterior continha apenas LocalizedConfig/GamesBrowserURL, como irmão do nó AppDirConfig. Isso era uma incompatibilidade verificável e uma possível causa de o botão Jogos não conseguir localizar o catálogo.

## O que foi publicado

Servidor: AEROCOOL, projeto Docker Compose storm-msn.
Template fonte: /mnt/user/appdata/msn/upstream/front/msn/tmpl/MsgrConfig.wlm.14.xml.
Template do contêiner: /app/front/msn/tmpl/MsgrConfig.wlm.14.xml.

Foi adicionada uma única entrada GamesBrowserURL em LocalizedConfig/AppDirConfig com o endereço https://msn.hoststorm.com.br/AppDirectory/Directory.aspx?from=wlm2009. O campo irmão mais antigo permaneceu no XML. O código local no AEROCOOL também foi ajustado para manter a correção em futura construção de imagem a partir desse checkout. O checkout tem outras alterações locais não consolidadas; nenhuma delas foi reescrita, revertida ou submetida ao main nesta operação.

Foi usado backup antes da alteração, cópia de arquivo para contêiner por Docker e movimentação de arquivos sem reconstrução nem reinicialização do serviço. Backup da aplicação aprovada:

/mnt/user/appdata/msn/backups/wlm-games-config-20261107T031445Z

SHA-256 após a mudança: 25d43b77783dbb6ed52d1c0790724e39cc5cb888cc46040ca51106c3045efe99.

Uma primeira execução foi revertida automaticamente porque a URL pública /api/health retorna 404 a partir do AEROCOOL, embora responda 200 da Oracle. A segunda aplicação passou utilizando a rota correta de saúde do loopback, sem reiniciar o contêiner. Não houve perda de dados ou alteração de banco.

## Validação pós-publicação

- Contêiner storm-msn: running / healthy.
- Saúde local em http://127.0.0.1:18081/api/health: OK.
- Configuração pública em https://msn.hoststorm.com.br/etc/MsgrConfig?ver=14.0.8117.0416: HTTP 200 e XML válido.
- LocalizedConfig/AppDirConfig/GamesBrowserURL: presente, URL correta.
- LocalizedConfig/GamesBrowserURL: mantido e igual ao valor nativo.
- Sonda pública probe_games_appdir.py --live: ok=true.
- Catálogo AppDirectory: 100 entradas consideradas na resposta de contrato.
- GetAppEntry SOAP: corresponde ao jogo de teste 673 e à URL do catálogo.
- Teste no próprio Windows do Nexus usando Invoke-WebRequest: HTTP 200, ambos os caminhos presentes.
- Serviços do catálogo na Oracle: ativos.
- Testes offline Node e Python para o renderizador real: aprovados.
- GitHub Actions da branch: sucesso.

## Limites e próxima validação

Essa correção não altera o executável Microsoft, os recursos DirectUI, os arquivos visuais nem as sessões do usuário. Não prova, sozinha, que o menu Jogos do cliente real abrirá. A janela original pode precisar reler o arquivo de configuração em um novo início de sessão do Messenger (não reiniciar o servidor).

O teste humano preparado continua em:

E:\StormMSN-Research\lab-native-2009\Testar-Jogos-MSN-Original.cmd

Na sessão gráfica do Nexus, executar o arquivo, abrir uma conversa com conta de teste e clicar no botão original Jogos. O coletor salva apenas classes e dimensões de janelas e se convdraweractivityhost surgiu, sem textos, contatos, mensagens, senhas ou screenshots.

Relatório esperado:

E:\StormMSN-Research\lab-native-2009\webview2-poc\build\ActivityProbe-Teste-Manual.txt

Se o botão abrir o catálogo, o passo seguinte será investigar o encaixe do Edge WebView2 na área correta da conversa, em uma cópia de laboratório. O componente Edge WebView2 separado e seu protocolo stormmsn-game:// permanecem disponíveis para o Nexus.

Não foi comprovada ainda execução real de jogo autenticado dentro do Messenger, multiplayer, voz ou vídeo.
