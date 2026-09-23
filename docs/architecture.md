# Arquitetura

## App iOS

`ContentView` oferece preparação, captura, importação de vídeo, replay e histórico. `WorkoutSession` coordena `AVCaptureSession`, análise, gravação opcional e estatísticas. `PoseDetector` integra `MediaPipeTasksVision` com modelos Lite/Full em modo vídeo. `SquatCounterCore` é uma biblioteca Swift sem UI/MediaPipe: recebe observações de pose, mantém fase com histerese e gera eventos de repetição; também persiste histórico e métricas auxiliares.

Fluxo ao vivo: câmera → buffer → pose MediaPipe → observação do núcleo → estado/evento → overlay e contagem. O caminho de vídeo importado processa o arquivo antes da reprodução e sincroniza resultados com o relógio do player. A gravação opcional guarda o vídeo da câmera sem overlay nos pixels e amostras separadas para replay. Os arquivos ficam locais no contêiner do app.

`Package.swift` testa o núcleo com `swift test`. `project.yml` gera os alvos iOS; `Podfile` instala MediaPipe. Os modelos `.task` devem estar em `ios/Sources/SquatCounter/Resources/Models/` antes de compilar. A fase de recursos inclui `Resources` uma vez e exclui a pasta da compilação Swift.

## Vídeo editorial

`video/src/index.tsx` registra vídeo e capa em 16:9 (`SquatCounterFinal`, `SquatCounterCover`) e 4:5 (`SquatCounterSocial`, `SquatCounterSocialCover`). `video/src/video.tsx` as monta a partir de mídia em `video/public/`. É um artefato editorial de um ensaio específico, não requisito para executar o app. Recursos foram intencionalmente omitidos do Git; os renders finais estão fora deste repositório e aguardam aprovação humana antes de publicar.

## Fronteiras futuras

Para M1–M4, manter interfaces distintas para captura/importação, inferência de pose, associação temporária de pessoa, máquina de estados **por atleta**, feedback revisável e armazenamento/replay. A posição na lista de poses não identifica um atleta. Uma sessão de várias pessoas exige estados, relógios, eventos e relatórios independentes; se o vínculo pessoa↔pose ficar ambíguo, interromper a contagem correspondente. O fluxo de ocupação agregada não deve depender da identidade do treino.

## Limites conhecidos

Importação atualmente aceita apenas vídeo horizontal sem rotação embutida. O tempo de treino configurado é referência visual e não encerra automaticamente a captura. A posição do overlay após rotação e o comportamento da câmera com pareamento Xcode exigem teste em aparelho físico. O contador não avalia técnica ou risco.
