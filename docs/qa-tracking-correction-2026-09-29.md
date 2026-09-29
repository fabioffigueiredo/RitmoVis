# Correção de perda do alvo — 29/09/2026

## Escopo e estado

Correção experimental da seleção de **um aluno** em vídeo importado. O proprietário autorizou encerrar a sessão manual, atualizar o app, executar diagnósticos no iPhone e enviar código/documentação ao GitHub. A automação de monitoramento de 26/09 está pausada. **M0/M2 e a beta continuam sem aprovação**; não há avaliação de técnica, treino de novos pesos ou validação Android.

Worktree: `RitmoVis/.worktrees/m2-android-a0`, branch `feat/m2-android-a0`. Aparelho físico: **iPhone de fabio**, iPhone 15, iOS 27.0.1, app `com.fabiofigueiredo.ritmovis.dev`. Instalação pelo Xcode/devicectl, sem apagar o contêiner. O acesso visual ao Device Hub voltou a exceder o tempo limite; os resultados abaixo vêm dos relatórios gerados **no aparelho**, não de uma observação remota da tela.

## Causas reproduzidas

1. **Candidato removido antes do rastreador:** o caminho Apple Vision truncava as observações com `prefix(4)`. No agachamento, a ordem retornada mudava e o aluno escolhido ficava além das quatro primeiras poses. A ordem do detector não é identidade. O limite foi removido nesse caminho; MediaPipe mantém sua configuração de quatro poses.
2. **Troca após uma lacuna curta:** a janela espacial do rastreador ampliava-se desde a última confirmação e permitia aceitar um colega já presente. Foi adicionado contexto temporário dos demais candidatos, conservando rivais ausentes até 0,45 s e abstendo-se quando a associação não é inequívoca. Não há reconhecimento facial ou ID nominal.
3. **Ciclo descartado por um único ângulo ausente:** identidade confirmada e joelho momentaneamente indisponível eram tratados como perda de identidade. `recordMissingMeasurement(at:)` mantém a fase por menos de 0,45 s desde a última medida válida, sem avançar fases nem criar ângulos. Ausência prolongada invalida o ciclo parcial; identidade incerta continua interrompendo-o imediatamente. Aplicado ao analisador offline e ao caminho ao vivo, mas o ensaio físico desta entrega é **offline**.
4. **Texto confundia detecção e seleção:** a lista filtrada era chamada “Pessoas detectadas”. Na escolha, agora mostra “Pessoas aptas à análise”, explica a visibilidade das articulações e avisa que mudar o modo requer nova importação. Estar em pé não é requisito geral da seleção; é diferente da calibração opcional e do início de um ciclo completo.

## Revisão crítica e regressões

A revisão GPT-6 Astra encontrou dois problemas na primeira versão do cache: a associação gulosa de um rival podia consumir o próprio alvo e liberar o colega; um rival ausente era apagado antes do prazo. Ambos foram reproduzidos em testes antes da correção. A versão revisada considera a competição entre âncoras, abstém-se na ambiguidade e preserva observações ainda válidas. Astra repetiu P1/P2, expiração e ponto intermediário, sem encontrar novo bloqueador concreto nesse escopo. Isto é revisão de código, não aprovação experimental de identidade.

Testes cobrem mudança da ordem/índices, roupas semelhantes, rival e alvo movendo-se, cruzamento, desaparecimentos alternados, expiração do cache, ângulo ausente curto/longo, identidade incerta, fundo do agachamento não observado e timestamps inválidos. Nenhum limiar de amplitude ou duração de fase foi relaxado para aumentar contagens.

## Evidência física do caso original

Mesmo arquivo privado de 316 quadros, 3840×2160, seleção em 0 s, Apple Vision, sem calibração. Baseline antigo executado novamente em 29/09 e build final executado após os ajustes da revisão. Os nove quadros foram marcados por inspeção visual do caso conhecido; são **regressão de ajuste, não conjunto independente**.

| Medida | Baseline antigo | Correção final |
|---|---:|---:|
| Quadros marcados com seleção correta | 1/9 | 9/9 |
| Quadros marcados com seleção de outra pessoa | 2/9 | 0/9 |
| Quadros marcados em abstenção | 6/9 | 0/9 |
| Quadros do clipe com decisão `selected` | 240/316 | 306/316 |
| Quadros incertos | 76 | 10 |
| Selecionado sem ângulo utilizável | 18 | 7 |
| Eventos automáticos de repetição | 0 | 3 |

**306 quadros selecionados não comprovam 306 identidades corretas. Três eventos não equivalem a três repetições manualmente validadas.** O ensaio final levou 6,62 s para processar o clipe, com média de inferência de 19,45 ms e p95 de 25,47 ms; zero quadros pretos e zero descartados. São números de processamento offline de um ensaio, não FPS sustentado da câmera.

Uma segunda seleção, em 1,0 s, com o aluno agachado, foi aceita no build final: 276 quadros selecionados, 10 incertos, zero pedidos de reseleção e dois eventos após esse ponto. Os primeiros 30 quadros ficam fora da seleção; o ciclo parcial anterior não deve ser creditado.

### Outros cenários repetidos no build final

| Cenário privado | Selecionados / total | Incertos / reseleção | Eventos | Limite |
|---|---:|---:|---:|---|
| 6AC: atleta à direita, escolha no início | 692/693 | 1 / 0 | 3 | Continuidade do estado, sem rótulo completo de identidade/ciclos |
| 6AC: tentativa de escolher o pôster em 0,1 s | 0/693 | 0 / 0 | 0 | Ficou no primeiro passe sem seleção; não prova rejeição de qualquer foto |
| D3: aluno em x≈0,388/y≈0,572 aos 2 s | 657/866 | 80 / 69 | 8 | Há perda/reseleção; 60 quadros anteriores à escolha excluídos. Contagens não anotadas |

O ensaio intermediário `fix2-D3.json` usou outra coordenada e escolheu outro candidato após a remoção do limite de quatro poses. **Não comparar seus zero eventos com os oito do ensaio final como ganho de contagem do mesmo aluno.** A variação de nomes/índices e a própria coordenada da escolha precisam ser preservadas no protocolo.

### Verificações automatizadas e preservação

- `swift test`: **66/66** aprovados na execução final.
- `xcodebuild test`: **71/71**, sendo 66 núcleo e 5 UI no simulador iPhone 15. Inclui replay/seleção sem recriar a análise, navegação, texto de elegibilidade, início após importação e rotação dos controles sintéticos. Não equivale a câmera física.
- `node --test tools/*.test.mjs`: **15/15** aprovados, incluindo nove testes do novo verificador de regressão.
- Build Debug assinado para iOS: aprovado e instalado. O índice do Histórico foi comparado byte a byte antes/depois e permaneceu idêntico; nenhum vídeo pessoal foi excluído.
- Xcode emitiu aviso na coleta auxiliar de diagnósticos do simulador (`simctl` fora do PATH do coletor), mas o teste terminou `TEST SUCCEEDED`, exit 0. O resultado estruturado está em `/tmp/ritmovis-correction-sim-final-20260929/Logs/Test/Test-SquatCounter-2026.09.29_20-23-44--0300.xcresult`. Avisos de APIs AVFoundation descontinuadas permanecem como dívida.
- Logs locais: `/tmp/ritmovis-correction-core-final.log`, `/tmp/ritmovis-correction-node-final.log`, `/tmp/ritmovis-correction-build-final.log` e `/tmp/ritmovis-correction-sim-final.log`.

## Uso no aplicativo

Antes de abrir Fotos/Arquivos, ative **Apple Vision para vídeos com grupo (experimental)**. Importe novamente o vídeo e toque no aluno. A opção permanece explícita e desligada por padrão; a câmera ao vivo continua com MediaPipe Lite/Full. Não use resultados antigos em cache para julgar a nova execução.

Na comparação intermediária do mesmo arquivo, MediaPipe Lite não aceitou a seleção no início; Full selecionou 16/316 quadros e passou a exigir reseleção. Estes ensaios antecedem o último refinamento do cache e não estabelecem resultado final de MediaPipe. Não anunciar que sua detecção foi corrigida nem promover um backend a padrão com base neste clipe.

## Reproduzir e preservar a evidência

Dados privados: `~/Library/Application Support/RitmoVis/qa-private/correction-20260929/`. Baseline, relatórios finais, marcações, índice do Histórico e visualização permanecem fora do Git. Fonte original copiada anteriormente do contêiner está em `qa-private/monitor-20260926/vision-retest-source.mov`; no aparelho, a cópia de QA se chama `qa-retest-20260929.mov`.

Vídeo privado `RitmoVis-antes-depois-20260929.mp4`: imagem original com overlays dos dois traços reais do iPhone, lado a lado. **Não é gravação da interface, nova inferência, vídeo público ou prova de precisão.** O script privado `render-comparison.mjs` verifica os 316 timestamps contra o vídeo fonte com tolerância de 3 ms e exporta duração variável por quadro; o último quadro é repetido apenas para fechar sua duração. A imagem `troca-de-pessoa-antes-depois.jpg` mostra especificamente 1,1 s. Não redistribuir essa mídia no GitHub/LinkedIn.

```sh
cd ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
# Na raiz do repositório:
node --test tools/*.test.mjs
node tools/check-tracking-regression.mjs /caminho/privado/final-vision.json /caminho/privado/critical-identity.json
```

O verificador exige a mesma fonte e correspondência única de timestamp (tolerância 3 ms), rejeita índices duplicados/ausentes e falha quando uma pessoa fora da região marcada está selecionada, mesmo se abstenção for permitida. A região representa o **centro da pose**, não segmentação ou identidade universal. As marcações privadas não entram no Git; os testes da ferramenta usam apenas dados sintéticos.

## Pendências e gates

- Rotular identidade e ciclos completos em mais trechos, separando ajuste e aceitação; medir trocas e cobertura útil, não apenas contagem de estados `selected`.
- Rever outros pôsteres/fotos, oclusões longas e roupas parecidas; o filtro existente não é detector universal de presença real.
- Comparar a versão final com MediaPipe em corpus independente e medir custo de mais candidatos Vision/eligibilidade em turmas maiores.
- Completar 50+ ciclos anotados, câmera sustentada por 10 minutos e QA físico de câmera/rotação/permissões. O problema ambiental de câmera preta no pareamento não é resolvido por esta correção de importação.
- Portar contratos ao Android apenas na etapa programada e testar em aparelhos físicos. Os testes Swift não validam Android.
- `noPoseFrames` ainda mistura ausência de seleção e medida; usar as categorias de `diagnostics` e o traço, não essa métrica isolada.
