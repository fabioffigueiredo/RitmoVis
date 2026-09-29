# Monitoramento dos testes de importação — 26/09/2026

**Estado em 29/09:** sessão manual encerrada e automação pausada. O proprietário autorizou correção e testes posteriores, descritos em [QA da correção](qa-tracking-correction-2026-09-29.md). As instruções abaixo de não reiniciar durante testes referem-se à sessão manual histórica, não impedem os ensaios de correção autorizados. Não reativar automaticamente a coleta periódica.

## Sessão de desenvolvimento

O proprietário autorizou acompanhar testes que ele próprio inicia importando vídeos no iPhone de fabio, e pediu acesso ao Xcode/Device Hub pelo computador, sem navegador. O workspace atual foi aberto no Xcode e o destino foi corrigido para **iPhone de fabio**, UDID `00008120-001468102EE2601E`. O aparelho estava conectado por cabo, mas despareado; `devicectl manage pair` refez o pareamento e o acesso ao contêiner do app funcionou. O acesso de interface ao Device Hub excedeu o tempo de resposta; isto impede afirmar que a tela do telefone está sendo vista remotamente. Os relatórios são lidos pelas ferramentas de dispositivos do Xcode.

O build Debug iniciado com `--qa-monitor-imports` continua permitindo importação por Fotos/Arquivos e escolha manual do aluno. O sinalizador só habilita diagnóstico; não escolhe alvo ou muda o modelo. Sem ele, esta coleta adicional fica desativada. Fechar o processo e reabrir o app pode perder o sinalizador; se os arquivos pararem de atualizar, confirmar isso antes de reiniciar qualquer teste.

O argumento foi configurado no editor de Scheme do Xcode (Run → Arguments), na máquina do proprietário. Em seguida, o botão Run executou o build final no destino físico, e a barra do Xcode confirmou `Running SquatCounter on iPhone de fabio`. Este ajuste de sessão fica na configuração gerada/local; XcodeGen pode recriá-la. Não ativar coleta como padrão de produto.

## Evidência salva localmente

`Documents/QAMonitoring/` contém JSON com nomes UUID imutáveis e uma cópia `latest.json`. Cada importação usa o mesmo `analysisID` nos eventos e nas reanálises após escolha de aluno. Tipos de registro:

- `analyzing-video` e `analyzing-selection`: início, fonte e, quando disponível, instante da escolha no vídeo.
- `first-pass-completed` e `selection-completed`: modelo efetivamente usado, eventos, contagens, desempenho e traço por quadro (candidatos, decisão, ângulo e centro do tronco quando disponível).
- `import-failed`, `analysis-failed`, `analysis-cancelled`, `selection-refused` e `calibration-refused`: mensagem e etapa que permitem localizar a tentativa.

Os traços não contêm assinatura de cor, reconhecimento facial nem identidade nominal. Vídeos e relatórios pessoais permanecem fora do Git. Os vídeos importados não são copiados pelo monitor automaticamente; uma cópia privada para investigar uma falha deve ser feita apenas se necessária.

## Acompanhamento da sessão

Automação de acompanhamento nesta conversa: `acompanhar-testes-de-v-deo-do-ritmovis`, a cada 5 minutos, até o fim de 26/09 no horário de São Paulo. É acompanhamento periódico de relatórios, não observação contínua da tela. Encerrar quando o proprietário terminar os testes. Não reinstalar, reiniciar, trocar detector ou cancelar análises durante os testes do proprietário.

Área privada de trabalho: `/Users/fabiofigueiredo/Library/Application Support/RitmoVis/qa-private/monitor-20260926/`. Ignore o baseline de preparação com `analysisID` `D99069D4-757B-4122-8016-1B80392C7916`. Arquivos já copiados servem como controle de deduplicação; pule `latest.json` na coleta dos registros imutáveis. Compare resultados do primeiro passe e da seleção, sem tratar ausência de seleção em grupo como falha. Conte apenas o trecho após a escolha ao calcular cobertura. Quadros sem ângulo, pausas e zero repetições precisam de contexto humano; não equivalem automaticamente a erro.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device info files \
  --device 00008120-001468102EE2601E --domain-type appDataContainer \
  --domain-identifier com.fabiofigueiredo.ritmovis.dev \
  --subdirectory Documents/QAMonitoring --no-recurse --timeout 15
```

Copiar cada arquivo novo com `device copy from`, fonte `Documents/QAMonitoring/<UUID>.json` e destino na área privada. Só avisar o proprietário com resultado novo relevante, falha observada ou pedido de ação específico. Sem novidades, aguardar a próxima execução. Para validar troca de identidade ou contagem errada, precisar do aluno escolhido, instante e contagem esperada, além de revisar o vídeo autorizado; os próprios traços não constituem verdade humana.

## Preparação verificada

Build assinado iOS aprovado e 54/54 testes do núcleo aprovados em 26/09. No iPhone físico, o clipe de referência com `--qa-monitor-imports --qa-clip-lite` criou evento de início e relatório completo em arquivos diferentes. O relatório registrou 743 quadros e 4 eventos; isto verifica a coleta, não precisão geral. Logs locais: `/tmp/ritmovis-import-monitor-build.log` e `/tmp/ritmovis-import-monitor-core.log`.

## Primeiro retorno do proprietário

Os primeiros vídeos importados pelo usuário geraram relatórios normalmente. No teste `DA3B8AD4-333B-4DD5-A00E-5F0D2BE4A37E`, MediaPipe Lite em modo vídeo, o proprietário confirmou que escolheu o aluno à frente de tênis branco. A seleção aos 2,1667 s acompanhou 24 quadros, teve 5 incertos e 222 que exigiram reseleção; 0 eventos. Última seleção confirmada: 3,0683 s. Aos 3,1017 s aparecem dois candidatos sobre a região do mesmo aluno, com centros do tronco separados por cerca de 0,015 em coordenadas normalizadas; a ambiguidade invalidou a seleção, e aos 3,135 s o estado virou `reselectionRequired`. A inspeção da imagem sugere pose duplicada do detector, mas não foi feita ainda a comparação com outro backend. Uma segunda escolha aos 9,97 s acompanhou somente os 17 quadros restantes; este trecho não serve para avaliar um ciclo completo.

Foi solicitado ao proprietário repetir o mesmo vídeo com Apple Vision, escolhendo o mesmo aluno perto de 2 s e deixando o trecho terminar sem reseleção. Não instalar outra versão enquanto esse comparativo estiver em andamento. A contagem manual completa ainda não foi informada/validada. Mídia e relatórios desse teste estão na área privada; nenhum peso ou regra do rastreador foi alterado durante a sessão.

## Reensaio Vision — troca de pessoa confirmada, 26/09

O proprietário informou que repetiu o mesmo vídeo e que o alvo ainda se perde; em alguns quadros só consegue escolher pessoas em pé. No relatório `A11CE692-47D4-47DA-9926-70726D1CC350`, seleção em 0 s, o iPhone registrou 316 quadros: 240 com decisão `selected`, 76 incertos, 18 selecionados sem ângulo utilizável e zero eventos. Sem quadros pretos ou descartados. O primeiro passe levou 7,18 s; isso é processamento offline, não desempenho de câmera. Uma tentativa anterior (`1E135B79-7A1B-4D0B-8857-5F7E960D9A24`) apresentou os mesmos totais. Há também um evento de cancelamento de outra importação; ele, isoladamente, não indica travamento.

A inspeção visual do vídeo correspondente e das caixas efetivamente registradas confirma **troca de identidade**, não apenas abstenção:

- 0,667 s: alvo selecionado é o aluno à frente, de camisa preta e tênis branco.
- 0,900–1,067 s: ele continua visível descendo, mas não consta na lista de candidatos; decisão incerta. O relatório não permite separar falha bruta do backend, limite das quatro poses e filtro de confiança.
- 1,100 s: a caixa selecionada passa ao colega à direita, de regata cinza; o aluno original continua visível.
- 1,133 s: o aluno original volta à lista de candidatos, mas a seleção permanece no colega.

Evidência privada: relatório `D1206D0B-3770-4234-98F5-F302A9AD67E4.json`, mídia copiada diretamente de `tmp/BC7830F5-B9EB-42BA-9AC3-DFB6BB18FBB9.mov` como `vision-retest-source.mov`, e painel `vision-retest-identity-switch.jpg` na área privada acima. O painel deriva dos quadros 20, 30, 33 e 34, com timestamps conferidos contra o vídeo; **não é captura da interface nem nova inferência**. Não versionar esses arquivos.

### Causas localizadas e limites

`TargetTracker` amplia a distância admitida conforme o tempo sem confirmação e usa geometria/resumo de cor do tronco. A troca observada demonstra que a proteção não impediu aceitar um rival após uma lacuna curta. O JSON omite a assinatura cromática e o tamanho do tronco, portanto não permite reconstruir integralmente a pontuação que levou à escolha; não atribuir o caso somente à cor da roupa nem apenas a um limiar.

Não existe regra geral exigindo estar em pé para detectar/selecionar. Porém, `VideoSelectionEligibility` esconde da seleção candidatos sem 12 quadros acompanhados, 10 com ângulo útil e proporção analisável de pelo menos 50% dos acompanhados nos próximos 2 s; a UI chama a lista filtrada de “Pessoas detectadas”. A criação de candidatos exige pelo menos oito pontos confiáveis, e o ângulo depende de quadril/joelho/tornozelo de um lado. São causas distintas que podem produzir a impressão de detecção apenas em pé. A calibração opcional e o início/reinício de ciclo, estes sim, exigem referência em pé. Uma única ausência de ângulo também interrompe o ciclo parcial em `OfflineTargetAnalyzer`.

Revisão crítica final com GPT-6 Astra confirmou a troca na evidência visual e a prioridade de integridade de identidade antes de flexibilizar contagem. Ressalva adicional: `noPoseFrames=316` mistura ausência de seleção com ausência de pose e contradiz os candidatos presentes; não usar essa métrica como falha de detecção. Não houve novo teste automatizado, pois esta etapa não alterou código; documentação passou em `git diff --check`.

**Gate M2 continua reprovado.** Nem 240 quadros `selected` nem o resultado anterior de 470/473 quadros e seis eventos demonstram identidade correta. Prioridades para a próxima correção, após a sessão do proprietário: regressão desta troca aos 1,1 s; separar detecção, elegibilidade e incerteza na UI/diagnóstico; distinguir perda de identidade de ausência momentânea de ângulo; preservar testes contra pôsteres e duplicações. Não relaxar confiança apenas para aumentar cobertura. Nenhum código, modelo ou instalação foi modificado nesta investigação.
