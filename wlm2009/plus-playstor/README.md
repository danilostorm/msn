# Storm MSN PlayStor — Messenger Plus! 5.02

Extensão de QA para o Windows Live Messenger 2009 original. Usa o Messenger Plus! 5.02 já instalado no Nexus para acrescentar um comando **Jogos PlayStor (Edge)** ao menu de scripts existente. O comando abre o catálogo em um processo Edge WebView2 local.

## Importação no Nexus

Pacote preparado: `E:\StormMSN-Research\lab-native-2009\plus-playstor\StormMSNPlayStor.plsc`.

1. Na janela original do MSN, abra **Plus! → Preferências e Opções → Scripts → Importar**.
2. Selecione o `.plsc` acima e aceite a importação, verificando o nome `Storm MSN PlayStor`.
3. Abra o menu de **Scripts** do Messenger Plus! e selecione `Jogos PlayStor (Edge)`.
4. A janela de catálogo será aberta no Edge WebView2. O login legítimo do PlayStor continua necessário para executar jogos.

Para remover a extensão, utilize o gerenciador de Scripts do Messenger Plus!. Não altera o navegador padrão, os contatos nem o executável original.

## Implementação e testes

- `Main.js`: JScript com `OnGetScriptMenu` e `OnEvent_MenuClicked`; executa apenas o caminho fixo para `StormEdgePlaystorLauncher.exe` no Nexus.
- `ScriptInfo.xml`: manifesto do Messenger Plus! 5.
- `tests/test_plus_playstor.js`: regressões de menu, despacho, caminho local e ausência de permissões de contato ou conversa.
- A extensão foi compilada como pacote `.plsc` (ZIP) no Nexus, com os dois arquivos no nível raiz, e validada estaticamente com Node e parser XML.

**Limites:** este caminho não faz o botão original Jogos deixar de ficar cinza e não incorpora WebView2 dentro de `convdraweractivityhost`. A extensão depende de confirmação de importação no Messenger Plus! e de um teste real do comando. Não reativa videochamadas, áudio nem partidas sincronizadas entre contatos. É um incremento útil, não um cliente com todos os recursos concluídos.
