# Estado de QA — extração de 2026-09-23

## Evidência herdada

O README do protótipo original relatava `xcodegen generate`, `pod install`, build em iPhone 15, 20 testes do núcleo e três testes de UI aprovados em 2026-09-18. Relatava quatro ciclos detectados em um clipe com modelos Lite e Full. O mesmo documento registrava quadros pretos nas duas câmeras quando o iPhone estava pareado ao Xcode, com imagem normal após cancelar o pareamento. Em 23/09 o proprietário informou que câmeras frontal/traseira, contagem e gravação funcionam no uso atual; isto ainda não foi repetido como QA formal neste repositório. Também não houve validação de 10 minutos de pose nem comparação com 50 repetições reais.

## Verificações desta extração

Em 2026-09-23, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` aprovou 20 testes do núcleo. `xcodegen generate` e `pod install` concluíram; `MediaPipeTasksVision`/`MediaPipeTasksCommon` foram instalados na versão 1.0.0. `xcodebuild` terminou com código zero para `generic/platform=iOS Simulator` e assinatura desligada, emitindo apenas avisos de APIs AVFoundation descontinuadas. O script de modelos baixou os dois arquivos oficiais e verificou os SHA-256 esperados. `npm ci --ignore-scripts` e checagem TypeScript do rascunho Remotion passaram.

Início de M0 em 23/09: foi adicionado o avaliador de anotações `RepEvaluator`, com quatro novos testes (24 testes de núcleo no total, todos aprovados), uma CLI local e um fixture **sintético**. O comando `swift run ritmovis-eval Fixtures/evaluation-synthetic.example.json` produziu TP=2, FP=1, FN=0, incluindo um falso positivo em tentativa incompleta. Esses números testam a ferramenta, não medem o aplicativo em pessoas reais. `xcodegen generate`, `pod install` e novo build iOS Simulator sem assinatura passaram após a inclusão do avaliador; persistem avisos de depreciação AVFoundation já presentes. Consulte `docs/m0-annotation-protocol.md`.

Teste de câmera em aparelho: pendente. Testes de UI neste novo repositório: pendentes. Renderização do vídeo **neste repositório**: indisponível sem os recursos omitidos. Uma peça 4:5 e uma 16:9 foram renderizadas e inspecionadas no projeto editorial de origem em 23/09/2026, mas não integram este Git; veja `docs/publication.md`.

## OBS e pareamento — diagnóstico, não correção

O OBS do Mac lista a câmera do iPhone por **Câmera de Continuidade**; o app iOS usa `AVCaptureDevice` local. Após o proprietário reconectar a câmera, a prévia das propriedades da fonte do iPhone no OBS passou a exibir imagem real do ambiente. Isso comprova quadros na rota iPhone → Mac/OBS naquele instante, mas não comprova que o contador iOS receba quadros com o pareamento ativo. A prévia preta anterior é inconclusiva porque houve desconexão durante a checagem. O teste A/B com OBS fechado/aberto, Câmera nativa, app e Xcode pareado/despareado ainda não foi executado: não alterar o estado do telefone sem combinar uma janela de teste. Registrar prévia física, luminância de gravação curta, notificações AVFoundation e logs. A falha observada com pareamento é correlacional; a causa permanece aberta.

## Critérios para uma alegação quantitativa

Registrar modelo, versão, aparelho/iOS, câmera, iluminação, ângulo, resolução, FPS, duração, quadros processados/sem pose, latência média/p95, repetições anotadas e detectadas, falsos positivos e falsos negativos. Repetir com amostras independentes. Um clipe de quatro ciclos apenas demonstra o funcionamento nesse clipe; não sustenta precisão geral nem avaliação da execução.
