# Histórico do iPhone — ruído e associação, 25/09/2026

**Origem:** `iPhone de fabio` físico, bundle `com.fabiofigueiredo.ritmovis.dev`. O índice e os sete MOVs gravados hoje foram **copiados**, sem apagar ou modificar o Histórico. Mídia e JSONs detalhados permanecem somente em `~/Library/Application Support/RitmoVis/qa-private/history-20260925/`; não entram no Git. Horários abaixo são BRT aproximados, derivados do índice do app. Contagens são as que o app registrou, **não** rótulos humanos.

| Hora | Sessão / cena observada | Eventos do app | Limite principal |
|---|---|---:|---|
| 07:04 | `EAA684B6`: um atleta em primeiro plano, pôster grande com outra pessoa ao fundo | 5 | possível falso candidato no pôster; posição e ângulo variam |
| 07:05 | `AC832C29`: trecho muito curto, piso do box sem pessoa visível na amostra | 0 | 36/36 quadros sem pose registrada no índice; controle negativo |
| 07:05 | `6AC874BC`: dois atletas agachando diante do pôster | 0 | alternância de candidatos, duplicatas e perda do alvo |
| 07:06 | `06B5A0EC`: trecho muito curto, piso do box sem pessoa visível na amostra | 0 | 43/43 quadros sem pose registrada no índice; controle negativo |
| 07:35 | `EB20EFCD`: dois participantes, ambiente aberto e movimento ao fundo | 7 | ainda sem atribuição manual ao aluno alvo |
| 08:09 | `9C6903CD`: atleta com interferência de outra pessoa/objeto | 2 | ainda sem atribuição manual |
| 08:18 | `D3E8365E`: turma, câmera móvel e oclusão parcial | 6 | não há ID-alvo de referência; ver reensaio em `qa-single-target-2026-09-25.md` |

Há também três sessões sem vídeo. O índice usa `noPoseFrames` para situações que podem incluir ausência de alvo selecionado; **não** equivale necessariamente a falha do detector. Não usar os eventos do Histórico como verdade de contagem, nem misturar estes vídeos de ajuste com o futuro conjunto de aceitação.

## Causa reproduzida e correção conservadora

No `6AC874BC`, a seleção de teste foi o atleta à direita no primeiro quadro com candidato. No simulador iPhone 15, MediaPipe Lite em modo `.video` gerou 210/693 quadros com múltiplos candidatos, mas só 9 quadros selecionados antes da correção. A linha do tempo revelou um salto do alvo de x≈0,58 para uma candidata em x≈0,36 em apenas 33 ms; a janela espacial fixa de 0,22 admitia essa troca. O teste `testOneFrameTeleportToOtherAthleteIsNotCredited` falhou antes da alteração e passou depois. O rastreador agora limita deslocamento de acordo com o tempo desde a última observação confirmada; saltos sem evidência pausam a contagem.

O modo MediaPipe `.image` (cada quadro independente) encontrou múltiplos candidatos em 677/693 quadros do mesmo clipe. Com o novo limite temporal, a seleção automática experimental do atleta à direita passou de **22 para 144 quadros selecionados**; nesses 144, a caixa selecionada permaneceu no lado direito (x>0,55), sem caixa selecionada em x<0,50. Ainda houve **528 quadros exigindo reseleção e zero eventos**. Isso é um ganho de cobertura parcial, **não** prova de ID correto em cada quadro, tampouco contagem confiável. Duplicatas de pose sobre o mesmo atleta e o pôster continuam sendo fontes de ambiguidade.

Comparação de controle: no clipe `EAA684B6`, com seleção de teste central, `.video` teve 482/585 quadros selecionados, nenhuma reseleção e 5 eventos; `.image` teve 325/585 selecionados, 222 em reseleção e também 5 eventos. Portanto o modo independente **não** substitui universalmente o padrão. Há agora uma opção explícita **“Análise quadro a quadro para grupos”** para o próximo vídeo importado; ela não altera a câmera ao vivo. A opção Apple Vision experimental tem prioridade caso ambas sejam ligadas. Vision não executou esse clipe no simulador (`Unable to setup request in VNDetectHumanBodyPoseRequest`); comparar no aparelho físico é trabalho pendente.

## Gate e próximos dados

- A correção evita o salto sintético reproduzido e os testes do núcleo passaram; isso não elimina ruído em qualquer cenário.
- Revisar manualmente alvo e repetição por quadro nos clipes consentidos, especialmente `6AC874BC`, `EB20EFCD` e `D3E8365E`; registrar professor/visitantes/pôster, oclusões e cruzamentos.
- Avaliar cobertura **e** trocas de pessoa em holdout separado. Se a pessoa correta sumir por tempo prolongado, manter abstenção e pedir nova seleção; não creditar outra pessoa para elevar cobertura.
- Testar o modo quadro a quadro no iPhone físico e medir duração, energia e memória antes de torná-lo automático ou de promover M2/beta.

## Verificação desta alteração

- Teste de regressão reproduzido em vermelho antes da correção e aprovado depois. `swift test`: **50/50** no núcleo.
- `xcodebuild test`: **55/55** no simulador iPhone 15/iOS 27, 50 núcleo + 5 UI; resultado `Passed` em `/tmp/ritmovis-m2-tracker-build/Logs/Test/Test-SquatCounter-2026.09.25_15-16-40--0300.xcresult`. O runner avisou que não conseguiu coletar diagnósticos adicionais com `simctl`; isso não alterou o resultado dos testes.
- Build assinado instalado por atualização no `iPhone de fabio` físico; o app iniciou. O SHA-256 do índice do Histórico antes/depois foi idêntico (`da5af8eb78b8900349d75fbac305a516c48729e4418214a7f34f7e214365be5f`). **Não** houve ensaio físico de rastreamento nesta atualização.
