# Estado de QA — extração de 2026-09-23

## Evidência herdada

O README do protótipo original relatava `xcodegen generate`, `pod install`, build em iPhone 15, 20 testes do núcleo e três testes de UI aprovados em 2026-09-18. Relatava quatro ciclos detectados em um clipe com modelos Lite e Full. O mesmo documento registrava quadros pretos nas duas câmeras quando o iPhone estava pareado ao Xcode, com imagem normal após cancelar o pareamento. Em 23/09 o proprietário informou que câmeras frontal/traseira, contagem e gravação funcionam no uso atual; isto ainda não foi repetido como QA formal neste repositório. Também não houve validação de 10 minutos de pose nem comparação com 50 repetições reais.

## Verificações desta extração

Em 2026-09-23, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` aprovou 20 testes do núcleo. `xcodegen generate` e `pod install` concluíram; `MediaPipeTasksVision`/`MediaPipeTasksCommon` foram instalados na versão 1.0.0. `xcodebuild` terminou com código zero para `generic/platform=iOS Simulator` e assinatura desligada, emitindo apenas avisos de APIs AVFoundation descontinuadas. O script de modelos baixou os dois arquivos oficiais e verificou os SHA-256 esperados. `npm ci --ignore-scripts` e checagem TypeScript do rascunho Remotion passaram.

Teste de câmera em aparelho: pendente. Testes de UI neste novo repositório: pendentes. Renderização do vídeo **neste repositório**: indisponível sem os recursos omitidos. Uma peça 4:5 e uma 16:9 foram renderizadas e inspecionadas no projeto editorial de origem em 23/09/2026, mas não integram este Git; veja `docs/publication.md`.

## OBS e pareamento — diagnóstico, não correção

O OBS do Mac lista a câmera do iPhone por **Câmera de Continuidade**; o app iOS usa `AVCaptureDevice` local. A fonte do OBS estar selecionada não comprova quadros válidos durante pareamento. Ao abrir a cena existente, a fonte estava oculta e a prévia em suas propriedades apareceu preta; o proprietário informou que desconectou a câmera durante a checagem. Essa prévia é inconclusiva e não equivale a um teste com fonte ativa. O teste A/B com OBS fechado/aberto, Câmera nativa, app e Xcode pareado/despareado ainda não foi executado: não alterar o estado do telefone sem combinar uma janela de teste. Registrar prévia física, luminância de gravação curta, notificações AVFoundation e logs. A falha observada com pareamento é correlacional; a causa permanece aberta.

## Critérios para uma alegação quantitativa

Registrar modelo, versão, aparelho/iOS, câmera, iluminação, ângulo, resolução, FPS, duração, quadros processados/sem pose, latência média/p95, repetições anotadas e detectadas, falsos positivos e falsos negativos. Repetir com amostras independentes. Um clipe de quatro ciclos apenas demonstra o funcionamento nesse clipe; não sustenta precisão geral nem avaliação da execução.
