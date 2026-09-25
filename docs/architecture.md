# Arquitetura

## App iOS

`ContentView` oferece preparação, captura, importação de vídeo, replay e histórico. `WorkoutSession` coordena `AVCaptureSession`, análise, gravação opcional e estatísticas. `PoseDetector` integra `MediaPipeTasksVision` com modelos Lite/Full em modo vídeo. `SquatCounterCore` é uma biblioteca Swift sem UI/MediaPipe: recebe observações de pose, mantém fase com histerese e gera eventos de repetição; também persiste histórico e métricas auxiliares.

Fluxo ao vivo (M2 inicial): câmera → buffer → até quatro poses MediaPipe → candidatos geométricos normalizados → `TargetTracker` → somente pose selecionada → `SquatCounter` → overlay e contagem. O índice da lista MediaPipe é local ao quadro, não um ID de aluno. Um toque seleciona uma observação recente pela geometria; se duas candidatas se aproximam demais, o rastreador se abstém e exige nova seleção. Uma ausência breve pode recuperar apenas quando a geometria ainda é plausível. A perda/ambiguidade chama `interruptTracking`, que descarta a repetição parcial sem apagar o total. Esse método não usa face nem descritor persistente; **pode errar** quando um visitante substitui o aluno sem cruzamento observável, e não passou no gate de vídeo real. O vídeo importado faz primeiro passe, guarda todas as poses e, para grupo, só aceita contagem após toque explícito. O toque aciona `OfflineTargetAnalyzer` no cache — não decodifica de novo nem recria `AVPlayer` — e só conta a partir daquele quadro. Apple Vision é opcional e experimental para vídeo de grupo; a câmera ao vivo continua MediaPipe. A gravação opcional guarda o vídeo da câmera sem overlay nos pixels e amostras separadas para replay. Os arquivos ficam locais no contêiner do app.

`Package.swift` testa o núcleo com `swift test`. `project.yml` gera os alvos iOS; `Podfile` instala MediaPipe. Os modelos `.task` devem estar em `ios/Sources/SquatCounter/Resources/Models/` antes de compilar. A fase de recursos inclui `Resources` uma vez e exclui a pasta da compilação Swift.

## Contrato entre plataformas

Na importação por Arquivos/Fotos, o app copia o arquivo para armazenamento temporário e analisa antes de reproduzir. `ImportedClipPolicy` determina, ao final da primeira análise, se houve mais de uma candidata em qualquer quadro; nesse caso o resultado inteiro é normalizado para zero eventos/contagens. O usuário pode tocar em uma candidata durante o replay pausado; `OfflineTargetAnalyzer` parte do timestamp selecionado usando `rawImportedResults` em cache. Quadros anteriores continuam sem contagem. O replay mostra caixas de candidatas por quadro, que **não são IDs persistentes**. Perda/ambiguidade deve suspender a contagem. Isto ainda não passou em corpus real anotado e não garante reconhecer todas as pessoas presentes. A calibração `standing-reference-v1` só pode ser solicitada pelo usuário num quadro em pé e só afeta aquela seleção; ver relatório M2.

`fixtures/tracking-v1-synthetic.json` define uma sequência versionada de observações, decisões e contagens. O teste Swift consome esse arquivo; Android A0 deverá consumir o mesmo JSON em Kotlin. Campos `index` e `expectedIndex` são apenas posições no resultado do **quadro**; `selectAfterIndex` representa o toque do usuário após aquele quadro. `uncertain` suspende contagem e invalida ciclo parcial; `reselectionRequired` impede recuperação silenciosa até novo toque. Tempo é monotônico dentro do clipe/sessão. O fixture não contém mídia ou identificadores pessoais e não mede qualidade de pose nem inferência. Contratos de avaliação reais deverão incluir plataforma, dispositivo, versão de OS, lente, pesos do modelo e eventos anotados sem publicar vídeo pessoal.

Android seguirá app nativo Kotlin + CameraX + MediaPipe, armazenamento privado e tela acesa só durante captura. O analisador CameraX deve descartar quadros sob sobrecarga sem bloquear a prévia e liberar cada `ImageProxy`, como especifica a [documentação oficial](https://developer.android.com/media/camera/camerax/analyze). Nenhum runtime Android ou aparelho físico foi testado ainda.

## Vídeo editorial

`video/src/index.tsx` registra vídeo e capa em 16:9 (`SquatCounterFinal`, `SquatCounterCover`) e 4:5 (`SquatCounterSocial`, `SquatCounterSocialCover`). `video/src/video.tsx` as monta a partir de mídia em `video/public/`. É um artefato editorial de um ensaio específico, não requisito para executar o app. Recursos foram intencionalmente omitidos do Git; os renders finais estão fora deste repositório e aguardam aprovação humana antes de publicar.

## Fronteiras futuras

Para M1–M4, manter interfaces distintas para captura/importação, inferência de pose, associação temporária de pessoa, máquina de estados **por atleta**, feedback revisável e armazenamento/replay. A posição na lista de poses não identifica um atleta. Uma sessão de várias pessoas exige estados, relógios, eventos e relatórios independentes; se o vínculo pessoa↔pose ficar ambíguo, interromper a contagem correspondente. O fluxo de ocupação agregada não deve depender da identidade do treino.

## Limites conhecidos

Importação atualmente aceita apenas vídeo horizontal sem rotação embutida. O tempo de treino configurado é referência visual e não encerra automaticamente a captura. A posição do overlay e seleção por toque após rotação exigem teste em aparelho físico. Em 24/09, a câmera nativa e a do RitmoVis ficaram pretas com cabo/pareamento enquanto o app recebia quadros quase pretos; veja `docs/qa-status.md`. O contador não avalia técnica ou risco.
