# Estado de QA — extração de 2026-09-23

## Evidência herdada

O README do protótipo original relatava `xcodegen generate`, `pod install`, build em iPhone 15, 20 testes do núcleo e três testes de UI aprovados em 2026-09-18. Relatava quatro ciclos detectados em um clipe com modelos Lite e Full. O mesmo documento registrava quadros pretos nas duas câmeras quando o iPhone estava pareado ao Xcode, com imagem normal após cancelar o pareamento. Também declarava que não houve validação de 10 minutos de pose nem comparação com 50 repetições reais. Esses resultados não foram repetidos automaticamente neste repositório.

## Verificações desta extração

Em 2026-09-23, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` aprovou 20 testes do núcleo. `xcodegen generate` e `pod install` concluíram; `MediaPipeTasksVision`/`MediaPipeTasksCommon` foram instalados na versão 1.0.0. `xcodebuild` terminou com código zero para `generic/platform=iOS Simulator` e assinatura desligada, emitindo apenas avisos de APIs AVFoundation descontinuadas. O script de modelos baixou os dois arquivos oficiais e verificou os SHA-256 esperados. `npm ci --ignore-scripts` e checagem TypeScript do rascunho Remotion passaram.

Teste de câmera em aparelho: pendente. Testes de UI neste novo repositório: pendentes. Renderização do vídeo: indisponível sem os recursos omitidos.

## Critérios para uma alegação quantitativa

Registrar modelo, versão, aparelho/iOS, câmera, iluminação, ângulo, resolução, FPS, duração, quadros processados/sem pose, latência média/p95, repetições anotadas e detectadas, falsos positivos e falsos negativos. Repetir com amostras independentes. Um clipe de quatro ciclos apenas demonstra o funcionamento nesse clipe; não sustenta precisão geral nem avaliação da execução.
