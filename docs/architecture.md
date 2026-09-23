# Arquitetura

## App iOS

`ContentView` oferece preparação, captura, importação de vídeo, replay e histórico. `WorkoutSession` coordena `AVCaptureSession`, análise, gravação opcional e estatísticas. `PoseDetector` integra `MediaPipeTasksVision` com modelos Lite/Full em modo vídeo. `SquatCounterCore` é uma biblioteca Swift sem UI/MediaPipe: recebe observações de pose, mantém fase com histerese e gera eventos de repetição; também persiste histórico e métricas auxiliares.

Fluxo ao vivo: câmera → buffer → pose MediaPipe → observação do núcleo → estado/evento → overlay e contagem. O caminho de vídeo importado processa o arquivo antes da reprodução e sincroniza resultados com o relógio do player. A gravação opcional guarda o vídeo da câmera sem overlay nos pixels e amostras separadas para replay. Os arquivos ficam locais no contêiner do app.

`Package.swift` testa o núcleo com `swift test`. `project.yml` gera os alvos iOS; `Podfile` instala MediaPipe. Os modelos `.task` devem estar em `ios/Sources/SquatCounter/Resources/Models/` antes de compilar. A fase de recursos inclui `Resources` uma vez e exclui a pasta da compilação Swift.

## Rascunho de vídeo

`video/src/index.tsx` registra vídeo e capa em 16:9 (`SquatCounterFinal`, `SquatCounterCover`) e 4:5 (`SquatCounterSocial`, `SquatCounterSocialCover`). `video/src/video.tsx` as monta a partir de mídia em `video/public/`. É um artefato editorial herdado, com referências a um ensaio específico; não é requisito para executar o app. Seus recursos foram intencionalmente omitidos. Os vídeos exigem revisão de evidência, autorizações e texto antes de renderizar ou publicar.

## Limites conhecidos

Importação atualmente aceita apenas vídeo horizontal sem rotação embutida. O tempo de treino configurado é referência visual e não encerra automaticamente a captura. A posição do overlay após rotação e o comportamento da câmera com pareamento Xcode exigem teste em aparelho físico. O contador não avalia técnica ou risco.
