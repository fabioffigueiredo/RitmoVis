# M2 — reensaio privado no simulador em 25/09/2026

**Escopo:** versão com resumo cromático temporário do tronco, associação conservadora e confirmação em dois quadros após uma lacuna. Os arquivos analisados são cópias privadas 720p/8 bits dos vídeos recebidos; o app rodou no **simulador iPhone 15/iOS 27**, não no iPhone físico. Relatórios completos e mídia permanecem em `~/Library/Application Support/RitmoVis/qa-private/new-videos-wtUpM1/` e não entram no Git.

| Trecho e seleção experimental | Quadros | Selecionados antes → agora | Sem pessoa detectada agora | Incertos / reseleção agora | Eventos agora |
|---|---:|---:|---:|---:|---:|
| `7209`, pessoa à direita `(0,77; 0,60)` | 473 | 62 → 227 | 2 | 46 / 200 | 1 |
| `7211`, candidata central inicial | 314 | 1 → 87 | 0 | 71 / 156 | 1 |
| `7212`, candidata central inicial | 316 | 49 → 48 | 1 | 1 / 267 | 0 |
| `7210`, 60–72 s, candidata central inicial | 359 | 1 → 354 | 0 | 5 / 0 | 1 |
| `7210`, 240–252 s, candidata central inicial | 359 | 152 → 151 | 10 | 4 / 204 | 0 |

**Leitura correta:** “selecionado” significa apenas que o rastreador escolheu uma pose; **não prova que seja a pessoa certa**. “Evento” é uma repetição computada, não uma repetição confirmada por humano. A melhora aparente em alguns trechos pode incluir troca de ID ou falso positivo. `7212` e `7210` aos 240 s praticamente não melhoraram. A separação entre `noDetectedPeople`, `identityUncertain`, `reselectionRequired` e `selectedWithoutUsableAngle` agora está no relatório DEBUG. Por exemplo, no `7209` houve só dois quadros sem nenhuma pessoa detectada, mas 246 quadros incertos ou exigindo reseleção: a maior parte da perda não era simplesmente “câmera sem pose”.

Em `7209` selecionado à direita, Lite processou 473 quadros, escolheu 227, inferência média de 16,95 ms; Full escolheu 216 e teve média de 17,56 ms no mesmo simulador. Esse ensaio isolado **não** demonstra que Lite seja melhor: é necessário conferir IDs e repetições no conjunto independente, além de latência e energia no aparelho real. Os relatórios Lite/Full preservam a linha do tempo e a versão exata do clipe. O caso preto-contra-preto ainda não foi anotado com referência humana e não pode ser dado como resolvido.

## Verificação automatizada e lacunas

- `swift test`: 46 testes do núcleo aprovados (inclui avaliação de identidade, categorias de falha e cruzamentos sintéticos).
- `xcodebuild test`: 51/51 aprovados no simulador (46 núcleo + cinco UI). O teste UI de reseleção primeiro falhou: após “Escolher outra pessoa ou ponto”, a caixa podia continuar rotulada “Pessoa acompanhada”; corrigido, reproduzido e aprovado. O runner ainda emitiu aviso ao coletar diagnósticos porque seu subprocesso não localizou `simctl`; o `.xcresult` registra **Passed**, 51/51.
- Faltam rótulos independentes, duas revisões humanas, ≥50 ciclos completos no holdout, 10 minutos de câmera ao vivo no iPhone físico, verificação de baixo contraste e ensaio em Android físico. Sem isso, **M2 e beta continuam reprovados**; nenhuma precisão, recall ou taxa de troca de ID é publicada.

Próxima execução: seguir o [roteiro de gravação](recording-protocol-single-target.md), etiquetar os clipes por sessão e preencher o contrato `TargetEvaluationInput`. Só depois comparar seleção correta, erros de pessoa e contagem. Evitar treinar um codificador de identidade ou um detector de pose do zero com quatro vídeos da mesma sessão.
