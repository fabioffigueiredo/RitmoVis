# Continuação de QA — 05/10/2026

Estado: perfil renovado, confiança no desenvolvedor existente autorizada pelo proprietário e app funcionando novamente; falha de acompanhamento reproduzida em novos ensaios físicos. Ferramenta de diagnóstico e confiabilidade de testes UI incrementadas. Nenhum gate de M0/M2, câmera ou beta foi aprovado.

## Evidência nova de 05/10

Branch `feat/m2-android-a0`, base `e9e6635`, iPhone de fabio físico (iPhone 15/iOS 27.0.1, UDID terminado em `2601E`), conectado por cabo e pareado, Developer Mode ativo. Antes de relançar, `devicectl device info processes` não encontrou processo RitmoVis/SquatCounter; não havia sessão do app a interromper. `lockState` informou `passcodeRequired: false` e `unlockedSinceBoot: true`.

O primeiro lançamento novo, com `--qa-private-clip=7209-qa-8bit.mp4 --qa-group-select --qa-target-after=0.5 --qa-target-x=0.77 --qa-target-y=0.60`, foi recusado por `FBSOpenApplicationErrorDomain 3 / Security`: assinatura, entitlements ou perfil não confiado. Isso não foi erro de tela bloqueada nem inferência executada.

O perfil incorporado ao build físico local foi criado em **24/09/2026 15:01:35 UTC**, TTL de sete dias, com expiração em **01/10/2026 15:01:35 UTC**. O certificado Apple Development ainda consta válido. O build físico normal falhou por perfil ausente; com `-allowProvisioningUpdates`, falhou também por **No Accounts**. Xcode Settings → Apple Accounts foi aberto e confirmou somente convite para entrar e botão **Sign In…**. A janela foi deixada disponível ao proprietário.

Após o proprietário informar que reconectou, Apple Accounts passou a mostrar a conta e Personal Team. Novo build físico com `-allowProvisioningUpdates` passou (exit 0), gerou perfil de **05/10/2026 14:21:49 UTC até 12/10/2026 14:21:49 UTC**, e a reinstalação no mesmo bundle passou. `codesign --verify --deep --strict` confirma assinatura válida local; entitlements do app/perfil concordam, e o perfil inclui o aparelho. Mesmo assim, a tentativa nova de iniciar 7209 Full foi recusada pelo mesmo erro Security/FBS 3.

Device Hub passou a responder nesta execução e o alerta físico foi lido: **Desenvolvedor Não Confiável**, explicando que os ajustes de gerenciamento impediam executar os apps do desenvolvedor existente. Após confirmação específica do proprietário, em Ajustes → Geral → Gestão de VPN e Dispositivo foi permitida somente essa conta Apple Development. Tela posterior confirmou confiança e RitmoVis **Verificado**; lançamento CLI passou. Nenhum PIN, novo certificado/conta, reinício, remoção de app, mudança de privacidade ou pareamento foi necessário. A confiança foi uma ação autorizada, não uma correção do rastreador.

Antes/depois das leituras e da reinstalação, o índice `Documents/WorkoutHistory/index.json` manteve SHA-256 `e4fcf7056cc8b82b4a263256c7d6196e7523fc8a3aa5764f30d00fa662b91ac3`. Isto prova igualdade do índice, não integridade individual dos vídeos. Depois da abertura, a tela física foi inspecionada pelo Device Hub; mídias/relatórios continuam privados. Os originais continuam no aparelho.

Verificação final nova: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`, em `ios/`, passou **123/123** testes de núcleo; `node --test tools/*.test.mjs` passou **29/29**, zero falhas/skips. Workspace completo passou **141/141** no simulador (123 núcleo + 10 UI + 8 hospedados), zero falhas/skips, `Test-SquatCounter-2026.10.05_15-26-19--0300.xcresult`. Build físico, instalação e abertura passaram. Ao encerrar todos os baselines, app foi relançado **sem flags** e tela de preparação normal confirmada no Device Hub às **15:36 BRT**; índice do Histórico manteve o mesmo hash após Vision e os experimentos independentes.

Build **Release do app iOS para simulador** também passou (`xcodebuild … -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`). Isso é distinto de `swift build -c release`, que verifica somente o núcleo no Mac, e não comprova assinatura/build Release para distribuição física ou beta.

## Novos ensaios físicos de importação

Mesmo arquivo normalizado `7209-qa-8bit.mp4`, vídeo de duas pessoas, 406×720; gancho de QA faz seleção explícita perto do ponto 0,77;0,60. Os três relatórios novos confirmam `selection-completed`, fonte correta e `recordedAt` de **05/10**. Cada JSON foi copiado com nome único antes do próximo teste. Nenhuma contagem humana esperada foi definida.

| Modelo / seleção | Quadros totais / selecionados | Incertos / reseleção | Eventos | Média / p95 (ms) | Data UTC |
|---|---:|---:|---:|---:|---|
| Full, 0,5 s | 473 / 201 | 27 / 230 | 1 | 44,47 / 57,11 | 14:32:51 |
| Lite, 2 s | 473 / 180 | 119 / 114 | 0 | 31,09 / 36,85 | 14:33:34 |
| Full, 2 s | 473 / 156 | 27 / 230 | 0 | 41,89 / 49,93 | 14:34:56 |

Todos processaram o clipe completo, com zero descartes/quase pretos e até três candidatas. FPS de 22,21/31,63/23,54 são vazão da **análise offline**, não captura das lentes. A comparação Lite/Full com seleção em 2 s não mostra solução de utilidade: ambos tiveram zero eventos; os estados selecionados não comprovam ID correto. Full em 0,5 s reproduziu exatamente 201/27/230 de 30/09 e os mesmos tempos de primeira incerteza (2,0667 s) e reseleção (8,1 s). Lite em 2 s teve primeira incerteza em 2,0667 s e reseleção em 11,9667 s.

A tela física do Full confirmou “Pessoa perdida — escolha novamente” e “201/458 quadros acompanhados” no trecho a partir de 0,5 s; 458 é o denominador pós-seleção, distinto dos 473 quadros completos. Um evento automático não é um acerto anotado. Nenhum ajuste de limiar, modelo ou associação foi aplicado para produzir estes resultados.

## Falhas dos testes de interface e reparo

Suíte completa inicial: **132/134**, duas falhas, zero skips, `Test-SquatCounter-2026.10.05_11-23-38--0300.xcresult`. Falharam `testGestureInstructionsStayVisibleWithManualStopInBothOrientations` e `testGroupSelectionKeepsReplayAndShowsAnalysis`.

Os anexos AX mostram “Opções avançadas” em y690,7–719 e a seleção do replay em y681,3–733,3, enquanto “Iniciar treino” fixo ocupa y691–761. O centro dos dois controles estava sob a ação fixa. No teste de gesto aparece a tela de treino ao vivo no mesmo snapshot: o primeiro toque iniciou treino em vez de expandir opções, e a ausência do toggle foi consequência. No grupo, o replay continuou aguardando escolha e não houve aviso de análise. Não foi demonstrado bug de elegibilidade pelo teste.

Reparo **somente nos testes**: rolar controles até seus limites completos ficarem na área de conteúdo acima de Iniciar e abaixo da navegação; verificar posição além de `isHittable`; fazer isso antes de Opções avançadas, toggle, Selecionar e Escolher novamente. Não remover asserções, aumentar prazo de conclusão ou simular o resultado. Os dois testes focalizados passaram; revisão independente recomendou limites completos minY/maxY, incorporados. Suíte completa passou **134/134** às 11:37 BRT e, após acrescentar diagnóstico bruto, **141/141** às 15:26 BRT. Avisos de coleta de diagnóstico `simctl`/debugger e duas inversões internas de QoS continuam registrados, sem atribuição à captura física.

## Relatório pendente recuperado — execução de 30/09

`Documents/qa-camera-diagnostics.json` foi copiado **antes** da primeira tentativa de lançamento. Seu `recordedAt` é **2026-09-30T23:33:08Z**, não 05/10. Fonte: `qa-box-back-upright-20260930.mp4`, MediaPipe Lite, seleção manual de QA em 2,033 s, fim em aproximadamente 177,18 s.

| Métrica herdada | Resultado |
|---|---:|
| Quadros processados / descartados | 3.524 / 1.784 |
| FPS processados | 19,89 |
| Inferência média / p95 | 32,75 / 51,83 ms |
| Eventos / quadros quase pretos | 0 / 0 |
| `noPoseFrames` | 3.317 |

Fonte gravada usa fila de captura, sem lentes; `captureRunning: false` é esperado. Não é FPS de câmera real, benchmark controlado ou recall. `noPoseFrames` mistura ausência de alvo/ângulo útil e não comprova que o detector não viu pessoas. Não há contagem humana esperada para esse clipe.

## Primeira perda do 7209 — análise nova sobre traço antigo

O traço Full de 30/09 tem 473 quadros, 201 `selected`, 27 `uncertain`, 230 `reselectionRequired`, seleção inicial em 0,5 s. A ferramenta nova encontrou a primeira incerteza em **2,0667 s**: naquele quadro há somente a candidata à esquerda; o alvo da direita volta em 2,1 s. A inspeção do quadro do vídeo original mostra o atleta da direita ainda visível. Logo, faltou uma candidata de rastreamento correspondente ao alvo nesse quadro, não ocorreu troca demonstrada para o colega. O traço antigo não conserva todos os landmarks, confianças e motivos de filtro; isoladamente não separa falha bruta do detector de rejeição pelo filtro. A captura nova abaixo separa essas causas para esse quadro.

Mais tarde, até 8,0333 s o estado está `selected`; em **8,0667 s** aparecem duas observações com centros de tronco praticamente coincidentes no atleta da direita, além do colega à esquerda. A imagem tem dois atletas físicos e um pôster. O estado vira `uncertain`, seguido por **primeira reseleção em 8,1 s**, que persiste por 230 quadros. Isto sustenta a hipótese de poses duplicadas/contaminadas que ativam ambiguidade; sem landmarks completos não permite deduplicar com segurança nem provar a origem. **8,0667 s não é a primeira perda global**, e 230 quadros pedindo reseleção não são 230 perdas independentes.

O relatório Lite antigo ficou em **`first-pass-completed`, `selectionRequested: false`**. Não é comparação de rastreamento selecionado com Full. O gancho escolhe a primeira candidata próxima do ponto; a seleção real pode ser recusada por `VideoSelectionEligibility`, sem que o relatório inicial comprove o motivo. A recusa não autoriza contagem nem remoção do filtro.

Não foram relaxados limiares, congelada identidade, deduplicadas poses ou promovido um modelo. Duas caixas próximas podem pertencer a pessoas diferentes em cruzamento; um patch que escolhe a maior/confiante por proximidade pode fazer uma contagem cruzada.

## Incremento implementado

`tools/summarize-first-tracking-loss.mjs` lê **localmente** um relatório de importação e preserva fonte/data efetiva, distingue seleção explícita, automática e ausente (`selectionMode`), relata primeira perda de seleção (incluindo `noSelection`) e primeira reseleção separadamente, e contabiliza transições versus quadros em estado absorvente. Primeiro passe individual pode conter `selected` automático, conforme o produtor real; isso não significa escolha explícita concluída. Recusa timeline não crescente, estados desconhecidos, seleção sem candidata correspondente, índices duplicados e estágio contraditório com `selectionRequested`. Não adjudica identidade, repetições ou causa do modelo e não envia dados.

```sh
node tools/summarize-first-tracking-loss.mjs <RELATORIO_PRIVADO.json>
```

TDD: testes escritos primeiro; após acrescentar apenas o transporte CLI, cinco expectativas falharam por ausência do resumo/validação; implementação mínima passou cinco. Casos adicionais de integridade falharam e passaram após validação. Revisão encontrou uma rejeição incorreta de primeiro passe individual com seleção automática; contrato real conferido em `WorkoutSession`, novo teste falhou antes da correção e passou com `selectionMode` e suporte a `noSelection` após estado selecionado. Suíte Node final: **29/29**, oito testes novos. Fixtures dos testes são sintéticos; nenhum vídeo, pose extraída ou relatório pessoal foi versionado.

## Diagnóstico bruto opt-in — implementado e repetido no iPhone

O relatório de importação DEBUG ganhou `rawPoseDiagnostics` opcional, somente com `--qa-raw-pose-diagnostics` **e** `--qa-private-clip=<nome>` cujo arquivo efetivo corresponde a Documents/<nome>. Outras importações, primeiro argumento vazio/traversal e fontes remotas não são autorizadas pela política; o relatório de câmera não usa esse gancho. Sem opt-in o campo é ausente. A política reinicia em cada geração de relatório, preserva PTS crescente e captura só ±0,1 s de 2,0667/8,0667 s, no máximo 16 quadros por janela, 32 no total. Não altera o detector nem o rastreador.

Cada pose conserva seu índice original e todos os landmarks retornados, incluindo poses sem candidata, com x/y/visibility/presence e índice do ponto. `hasTrackingCandidate` significa **presença no array de candidatas**, não elegibilidade de seleção. `confidence` é a confiança do trio quadril/joelho/tornozelo escolhido para o ângulo, **não probabilidade global de pessoa**. Valores não finitos são omitidos para não quebrar JSON; coordenadas finitas não são limitadas/clampadas. Nenhum pixel, frame, aparência, cor, assinatura ou ID de pessoa é acrescentado ao JSON. Resultados extraídos continuam privados, fora do Git.

TDD: cinco testes de política/serialização produziram 12 falhas de asserção com stubs e passaram com a implementação; teste hospedado do adaptador produziu quatro falhas e passou preservando duas poses (a primeira rejeitada e a candidata com índice original 1), 33 pontos, sem aparência. O sexto teste core exigiu correspondência com a URL privada real: RED de uma asserção → GREEN. Fixtures são sintéticos. A leitura do produtor confirmou que `PoseDetector` conserva o array completo antes do filtro geométrico; o adaptador percorre `poseOptions`, não apenas candidatas.

Novo Full 7209, mesma seleção 0,5 s/0,77;0,60: relatório **2026-10-05T18:26:52.936Z**, `selection-completed`, 473 quadros, **201 selecionados/27 incertos/230 reseleção**, um evento não validado, zero descartes/quase pretos; média/p95 38,55/45,79 ms, 25,46 FPS offline. Campo bruto contém **12 quadros**, cada pose com 33 pontos; o comportamento de rastreamento foi idêntico ao baseline.

Achados novos: em **2,0667 s** existe somente a pose bruta do atleta à esquerda, já aceita como candidata. Não há pose rejeitada escondida do atleta à direita, embora ele continue visível no frame privado. A lacuna vem da saída do modelo, antes do filtro do app; o alvo volta em 2,1 s. Em **8,0667 s** existem três poses brutas: uma à esquerda e duas que compartilham cabeça/quadril/perna sobre o mesmo atleta à direita, não sobre o pôster ao fundo. Todas têm candidata. Uma das duas diverge sobretudo no braço com baixa visibilidade. O app se abstém e exige reseleção em 8,1 s. A duplicação observada na saída do modelo sustenta a causa de ambiguidade desse trecho, mas não prova uma regra geral segura de remoção.

Próxima correção mínima candidata: experimento isolado de identificação de poses duplicadas por concordância anatômica, com regressões negativas de cruzamento/oclusão/pessoas próximas e abstenção preservada. Não escolher cegamente a pose mais confiante nem alterar thresholds, recuperação de identidade, ROI ou modelo. Esse patch **não foi implementado nem aprovado** nesta execução; a instrumentação elimina a lacuna de evidência sem alegar melhoria de contagem.

## Comparação pareada de baselines existentes — seleção em 0,5 s

Mesmo arquivo 7209, ponto 0,77;0,60, rastreador/calibração inalterados, clipe completo de 473 quadros e diagnóstico bruto opt-in. Cada execução confirma backend efetivo e `selection-completed`; zero descartes/quase pretos. O modo IMAGE foi ativado pelo experimento **já existente** `--qa-independent-frames`, não virou padrão. Não foram baixados/substituídos/treinados pesos.

A [documentação oficial de Pose Landmarker para iOS](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/ios), consultada em 05/10, distingue IMAGE e VIDEO e descreve uso de rastreamento interno para reduzir trabalho de detecção no modo de vídeo. Isso justifica a comparação, não prova a causa interna da ausência/duplicação nem identidade persistente. A duplicação observada também em IMAGE impede atribuí-la exclusivamente ao estado do modo VIDEO.

| Backend efetivo | Selecionados / incertos / reseleção | Primeira perda / reseleção (s) | Eventos não validados | Média / p95 (ms) | Data UTC 05/10 |
|---|---:|---:|---:|---:|---|
| MediaPipe Full VIDEO | 201 / 27 / 230 | 2,0667 / 8,1 | 1 | 38,55 / 45,79 | 18:26:52 |
| MediaPipe Full IMAGE | 191 / 2 / 265 | 6,4333 / 6,9333 | 3 | 37,00 / 54,04 | 18:30:55 |
| MediaPipe Lite VIDEO | 225 / 119 / 114 | 2,0667 / 11,9667 | 1 | 26,98 / 31,77 | 18:32:26 |
| MediaPipe Lite IMAGE | 206 / 111 / 141 | 6,4333 / 11,0667 | 3 | 27,34 / 37,86 | 18:33:06 |
| Apple Vision | 421 / 37 / 0 | 9,1667 / ausente | 7 | 7,93 / 11,02 | 18:34:46 |

Em IMAGE, ambos modelos entregam a pose do atleta à direita em 2,0667 s, ausente em VIDEO. Porém Full IMAGE tem ausência completa em 6,4333 s e ambiguidade com troncos coincidentes em 6,9 s, entrando em reseleção **mais cedo**; ainda conserva a duplicação à direita em 8,0667 s. Lite IMAGE também exige reseleção antes de Lite VIDEO e tem menos quadros selecionados. Três eventos em vez de um não são três acertos: falta contagem/identidade anotada. Esse par não sustenta promover IMAGE nem atribuir toda duplicação ao estado interno do modo VIDEO.

Apple Vision foi executado uma única vez, com `--qa-apple-vision` existente; backend real confirmado `Apple Vision VNDetectHumanBodyPoseRequest`, mesma seleção e EOF. Nas duas janelas críticas há três poses — pôster e dois atletas — e a selecionada permanece sobre o atleta da direita. Seu array interno mapeia joints Vision para 33 posições; pontos não mapeados são zeros de confiança, **não 33 landmarks originalmente inferidos por Vision**. Maior cobertura de decisões `selected` e ausência de reseleção tornam esse baseline prioritário para anotação completa, não promovido: faltam identidade/ciclos humanos e sessão independente. Seus 118,12 FPS são vazão offline de um clipe curto, não FPS de câmera. `noPoseFrames: 473` conserva a métrica do primeiro passe anterior à seleção e não contradiz a presença de poses nem mede recall; não usar esse campo agregado para validar o detector.

Próxima fase implementável, separada por responsabilidade: (1) anotar privadamente identidade/ciclos de um clipe completo e seus quadros críticos; (2) comparar **detector → array bruto → construção de candidatas → TargetTracker → contador**, sem inventar pose/ângulo quando o detector falha; (3) reproduzir uma duplicação em teste isolado de concordância anatômica e exigir negativos de cruzamento/oclusão antes de integrar uma regra; (4) somente se a evidência continuar apontando a captura de pose, discutir **ROI-pose como proposta arquitetural distinta**, com aprovação/design e avaliação antes de implementação. Não confundir detector de pessoas, pose na ROI e acompanhamento do alvo: são módulos com falhas e gates próprios. Esta execução não muda arquitetura nem generaliza os achados do 7209 para todos os vídeos do box.

Preservar também a regressão de troca de pessoa confirmada em Vision em 26/09 ([histórico](project-history.md), [monitoramento](monitoring-imports.md#reensaio-vision--troca-de-pessoa-confirmada-2609)): o resultado favorável em 7209 não encerra esse risco. Reexecutar o caso adverso no código atual e num clipe independente, em vez de escolher somente o exemplo favorável.

## Revisão final e adjudicação

GPT‑6 Astra revisou código/testes da instrumentação, JSON Full VIDEO/IMAGE, imagens privadas dos instantes críticos e JSON Vision. Aprovou diagnóstico e interpretação, **não tracking, precisão, câmera, M0/M2 ou beta**. O principal reexecutou 123 testes de núcleo Mac/29 Node e conferiu o resultado Xcode 141/141 no simulador.

A sequência `selected` em 8,0333 → `uncertain` em 8,0667 → reseleção em 8,1 é compatível com a invalidação por ambiguidade no ranking de `TargetTracker`, não timeout naquele instante. É inferência apoiada no código; scores/aparência não foram persistidos e não revelam a origem interna do erro do modelo. Próximo experimento: hipóteses de correspondência temporais em modo offline/shadow, preservando poses concorrentes e abstenção, com negativos de pessoas reais próximas/cruzando. Não remover automaticamente uma observação por caixa ou confiança de perna. Fallback IMAGE somente no instante de ausência é outra hipótese a testar, não padrão aprovado.

Vision deve primeiro ter seus sete eventos e identidade conferidos no clipe completo. Foi solicitada ao proprietário a contagem manual do atleta à direita a partir de 0,5 s; resposta ainda pendente nesta entrega. Uma contagem total coincidente, sozinha, não comprova autoria de cada evento nem ausência de perdas/duplicações. O principal conferiu novamente a tela de preparação normal do iPhone de fabio no Device Hub às 15:40 BRT, sem iniciar câmera ou treino.

Após a conferência final, o principal encerrou o Device Hub usando **Quit and Keep Simulators Running**; inventário confirmou `isRunning: false` e `devicectl` ainda encontrou o processo RitmoVis no telefone. Não cancelou pareamento, encerrou Xcode, apagou dados ou fechou simuladores. Isso deixa a visualização remota fora do próximo teste físico; não comprova que câmera preta foi corrigida, pois as lentes não foram retestadas nesta etapa.

Reprodução local (substituir apenas dispositivo; clipe permanece privado em Documents):

```sh
cd ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace SquatCounter.xcworkspace -scheme SquatCounter -destination 'platform=iOS Simulator,name=iPhone 15,OS=27.0' CODE_SIGNING_ALLOWED=NO test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device process launch --device '<DISPOSITIVO>' --terminate-existing com.fabiofigueiredo.ritmovis.dev --qa-private-clip=7209-qa-8bit.mp4 --qa-group-select --qa-target-after=0.5 --qa-target-x=0.77 --qa-target-y=0.60 --qa-model-full --qa-raw-pose-diagnostics
```

Antes de relançar, verificar ausência de sessão ativa; copiar `Documents/qa-clip-diagnostics.json` para nome privado único após `selection-completed`, fonte/data novas e EOF. Ao terminar relançar sem flags. Não enviar JSON extraído ao GitHub.

## Bateria limitada e passo de produto

A conta existente e o perfil do **mesmo** team/bundle já foram revalidados, com build/reinstalação e hash preservado. Confiança aplicada após alerta exato e confirmação específica; não apagar app/Histórico para futuras renovações.

| Caso preparado | Método | Estado em 05/10 |
|---|---|---|
| 7209 Lite, alvo à direita em 2 s | Importação no telefone | Concluído, seleção confirmada; 0 eventos e perda do alvo |
| 7209 Full, seleção em 0,5 s e 2 s | Importação no telefone | Concluídos; perda do alvo reproduzida |
| Box traseira, alvo em 2 s / ponto 0,45;0,43 | Importação no telefone; arquivo já em Documents | EOF em 14:39:16 UTC; 5.308 quadros, zero eventos; primeiro passe sem seleção confirmada |
| Box frontal, seleção central | Fonte gravada no caminho de captura; arquivo em QAPrivateClips | EOF em 14:45:32 UTC; 4.722 processados/2.217 descartes; um evento não validado |
| Full 7209 com diagnóstico bruto | Importação no telefone, mesmas opções 0,5 s | EOF em 18:26:52 UTC; 12 quadros privados críticos e baseline de rastreamento preservado |

Box traseira: relatório `first-pass-completed`, `selectionRequested: false`, zero quadros selecionados, zero descartes/quase pretos, até quatro candidatas, média/p95 36,89/53,49 ms e 26,85 FPS **offline**. Tela informou zero pessoas elegíveis no instante solicitado; frame privado em 2 s mostra desfoque forte, câmera inclinada e corpos parciais. Não se demonstrou rastreamento desse alvo, nem foi relaxada elegibilidade para forçar escolha.

Box frontal gravado: seleção manual central simulada em 0,6333 s, índice 0, EOF em 231,5348 s; 20,394 FPS da **fila de captura com arquivo**, média/p95 32,328/48,642 ms, zero quase pretos, `noPoseFrames` 3.779. Um evento automático em 193,8667 s não é contagem humana nem confirmação de alvo correto. `captureRunning: false` no EOF é esperado para esse modo sem lentes. JSON final foi recuperado após a pausa do agente, conferido/copiado com nome único e data **05/10**, distinto do relatório pendente de setembro.

Cada execução deve ser copiada com nome único antes da próxima; conferir `source`, `recordedAt`, `stage` e `selectionRequested`. Se Lite permanecer no primeiro passe, registrar a recusa e escolher outro instante observável; não comparar como seleção concluída. Priorizar quadros em 2,0667 s e 8,0667 s com todos os candidatos/landmarks antes de propor correção. Um experimento de remoção de duplicata só cabe isolado, comparado com cruzamentos e roupas iguais, com abstenção preservada quando não houver evidência.

Passo mínimo de produto: piloto individual de agachamento, telefone apoiado, corpo inteiro e seleção explícita; revisar contagem e falhas em clipe completo anotado. A utilidade no box com várias pessoas continua falhando nos dados existentes. Vision 7209 é candidato para a próxima anotação, não uma validação de box/câmera. Primeiro demonstrar continuidade e contagem nesse escopo restrito; controle por gesto, câmera móvel, técnica, turma e beta têm gates próprios. Nenhum peso foi treinado/substituído.

Dados privados recuperados e quadros inspecionados: `~/Library/Application Support/RitmoVis/qa-private/qa-20261005/`, fora do Git. Não publicar.
