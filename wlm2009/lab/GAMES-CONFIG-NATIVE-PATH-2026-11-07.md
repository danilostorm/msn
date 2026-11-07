# Storm MSN 2009 — correção da configuração nativa de Jogos

Data: 7 de novembro de 2026. Branch: feat/wlm2009-original-fidelity.

## Descoberta

O executável Microsoft original (14.0.8117.0416) contém o caminho de configuração LocalizedConfig/AppDirConfig/GamesBrowserURL, observado no Ghidra no endereço 0x004333D0.

A resposta pública de https://msn.hoststorm.com.br/etc/MsgrConfig?ver=14.0.8117.0416 entrega apenas LocalizedConfig/GamesBrowserURL, como irmão do nó AppDirConfig. O caminho aninhado esperado pela rotina nativa está ausente. Isto pode explicar por que o botão Jogos não abre o catálogo no cliente original. É hipótese técnica, ainda não confirmada com clique real.

O XML público é renderizado pelo contêiner Storm MSN do AEROCOOL, usando front/msn/tmpl/MsgrConfig.wlm.14.xml, por meio de front/msn/http/other.py::_get_msgr_config. Não é originado no serviço do catálogo da Oracle.

## Correção pronta apenas na branch

- O template WLM14 agora fornece GamesBrowserURL dentro do AppDirConfig e preserva o nó irmão antigo.
- O gateway PlayStor configPatch adiciona o campo aninhado mesmo se o campo irmão existir; a transformação é idempotente.
- O teste público de AppDirectory agora rejeita a configuração antiga, evitando falsos positivos.
- Fixtures e testes de PlayStor foram corrigidos para links de execução direta com ?play=, preservando o login normal.
- Novo test_original_msgrconfig_runtime.py executa a função real de renderização do backend em ambiente isolado, sem iniciar o serviço nem acessar dados dos usuários.

## Validação

- Testes offline de catálogo Node: aprovados.
- Testes do contrato AppDirectory: 11 aprovados.
- Testes do renderizador original do backend: 7 aprovados; versões 8, 14 e 15 verificadas.
- Simulação sobre o XML público anterior: válido, valor aninhado correto, valor irmão mantido.
- O teste público --live ainda falha de forma esperada até a futura publicação do template no servidor principal.

A tentativa de alterar somente o gateway Oracle foi revertida automaticamente: a URL pública de configuração usa o contêiner principal AEROCOOL. Não foi feita nova publicação nesse contêiner.

## Pendente

A correção deverá ser publicada de forma controlada no servidor principal quando autorizada. Após a confirmação de que a URL pública já inclui ambos os campos, será necessário um teste com conversa original no Nexus para verificar o botão Jogos.

O kit do teste já está preparado em:
E:\StormMSN-Research\lab-native-2009\Testar-Jogos-MSN-Original.cmd

O observador registra apenas classes de janela, dimensões e identificadores da área de atividades, não textos, senhas, contatos ou conversas.

Nenhum executável Microsoft foi modificado. A implementação corrigida não é prova de que um jogo, voz ou vídeo já funcionem no MSN original.
