# Seleção no vídeo de grupo — 24/09/2026

## Causa e correção implementada

O toque reiniciava a inferência e recriava o AVPlayer. Agora a primeira análise guarda todas as poses; selecionar recalcula somente rastreamento/estados no cache, fora da thread principal, mantendo player e tempo. Tokens impedem que uma tarefa antiga sobrescreva outro vídeo. Antes da seleção, grupos não recebem contagens; perda/ambiguidade descarta ciclo parcial e exige nova seleção.

O zero tinha duas outras causas observadas: MediaPipe retornava candidatos instáveis/duplicados neste clipe, e o ângulo de topo estimado não chegava ao limiar padrão de 155°. Não confundir correção do replay com validação de identidade.

## Experimentos no iPhone de fabio

iPhone 15 físico, iOS 27, bundle de desenvolvimento `com.fabiofigueiredo.ritmovis.dev`. Clipe Pexels 6740245, 17,2 s, 1920×1080, 430 quadros. Relatórios privados ficam em `~/Library/Application Support/RitmoVis/qa-private/`, fora do Git.

| Configuração | Observação limitada a este clipe |
|---|---|
| MediaPipe Lite/Full direto | Candidatos instáveis/duplicados; seleção perdeu associação cedo; zero contagens |
| Vision sem calibração | 313 quadros acompanhados desde o início; perda em 12,52 s; zero contagens |
| Vision + MediaPipe recortado | 313 quadros acompanhados; média ~358 ms de inferência; zero contagens; não adotado como padrão |
| Vision + referência em pé no quadro 0 | 3 eventos: 2,40 s, 5,00 s, 10,40 s; 313 acompanhados, 1 incerto, 116 exigindo reseleção |

Último relatório calibrado: média 13,23 ms, p95 18,79 ms, 6,14 s para análise offline dos 430 quadros. Não são FPS de captura ao vivo nem tempo de resposta do toque. Referência inicial 146,20°; limiares usados 136,20°/101,20°. Não há anotação humana completa independente deste clipe: **3 eventos não significam 3/3 nem precisão validada**. A pessoa fica perdida no final; M2 ainda não passa o gate.

Campo legado `noPoseFrames` conta ausência de pose selecionada/ângulo, não necessariamente ausência de pessoas. No primeiro passe de grupo pode registrar 430 apesar das detecções. Não usar esse campo como recall do detector. JSON e CSV agora registram backend/calibração e o JSON utiliza métricas finais do processamento, não do quadro do replay.

## Calibração experimental v1

Somente com confirmação explícita de que o quadro escolhido está em pé. Referência finita entre 130° e 180°, confiança mínima 0,65. Topo = min(155°, referência − 10°); fundo = min(105°, topo − 35°). Mantém histerese, duração mínima e tratamento de perda. Não corrige perspectiva 3D, não reconhece postura correta e pode sub/supercontar. Parâmetros exigem corpus anotado antes de promoção ao padrão e paridade Android.

O exemplo de grupo usa Vision; importações permitem escolher Vision experimental ou MediaPipe. Ao vivo permanece MediaPipe. Uma nova seleção reinicia a análise a partir dela, não acumula resultados de seleções diferentes.

## QA e limitações

- Núcleo Swift: 39 testes passaram, incluindo três testes novos de calibração (ciclo limitado pela vista, rejeição de referência inválida/baixa confiança e não contagem de oscilação pequena). Os dois testes positivos falharam antes da implementação e passaram depois.
- Antes da opção Vision: 41 testes (36 core + 5 UI) passaram no simulador; inclui seleção/reseleção mantendo replay.
- Após Vision: 43/44 passaram, com falha em `testGroupSelectionKeepsReplayAndShowsAnalysis`: a análise Vision retornou “Nenhum quadro analisável” no simulador. Não classificar como aprovado. A navegação está sendo repetida explicitamente com MediaPipe; Vision foi executado no aparelho físico.
- Teste UI automatizado físico não iniciou: perfil de `com.fabiofigueiredo.ritmovis.dev.uitests.xctrunner` ausente; tentativa de provisioning encontrou credencial Xcode inválida/“No Accounts”. Isso não impediu build/instalação do aplicativo com o perfil já existente. Não foi alterada conta/senha.
- Persistem avisos de APIs AVFoundation descontinuadas e inversão de prioridade no simulador.
- Reexecução final: **44/44 aprovados** (39 core + 5 UI), zero ignorados, em `Test-SquatCounter-2026.09.24_22-29-11--0300.xcresult`. O teste de seleção/reseleção usa MediaPipe explícito no simulador; isso não apaga a falha anterior de Vision. Perfil físico de UI permanece bloqueado.
- Câmera pareada, 50+ ciclos anotados independentes, cruzamentos reais, cobertura, falsos positivos e 10 minutos ao vivo continuam pendentes. Não liberar beta como validada.
- Revisão estática final com GPT-6 Astra: nenhum bloqueador adicional no diff incremental; corrigidos confirmação reaproveitada, proveniência de detector/calibração e flags que poderiam atingir câmera ao vivo. Reexecução física final repetiu 3 eventos e 313/430 quadros acompanhados.

## Fontes técnicas

- [MediaPipe iOS](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/ios): múltiplas poses não oferecem contrato de identidade nominal.
- [Apple Vision](https://developer.apple.com/documentation/Vision/detecting-human-body-poses-in-images): observações corporais com pontos/confiança, sem promessa de rastreamento persistente.
- [Clipe Mikhail Nilov/Pexels](https://www.pexels.com/video/a-group-of-people-exercising-in-the-gym-6740245/). Mídia não versionada; uso privado de QA, sem afirmações sobre a execução da pessoa filmada.
