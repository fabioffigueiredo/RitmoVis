# Handoff para Claude — RitmoVis

**Atualizado em:** 05/10/2026

**Continuação atual:** [QA de 05/10](qa-recovery-2026-10-05.md). Perfil renovado até 12/10; confiança somente na conta existente após alerta físico exato e autorização específica. App voltou a executar no mesmo bundle, sem apagar Histórico; índice idêntico. Relatório pendente recuperado é de 30/09, distinto dos três 7209 e dois box novos completos. Full 0,5 s reproduziu 201/27/230 e perdas em 2,0667/8,1 s; traseira não confirmou escolha, frontal gravado terminou com um evento não validado. Resumo local, interação dos testes UI e diagnóstico DEBUG opt-in privado/limitado de poses brutas implementados, sem modificar rastreamento/modelos: **123 núcleo/29 Node/141 Xcode**, zero falhas/skips. Nova captura bruta confirma ausência do alvo na saída do modelo em 2,0667 s e duplicação do atleta à direita em 8,0667 s; próximos experimentos devem proteger cruzamentos/oclusão antes de patch de associação. Sem retreinamento, gate ou publicação; não apagar Histórico como correção de assinatura.

**Estado mais recente — teste físico após desbloqueio:** [QA de fonte gravada no telefone](qa-physical-recorded-input-2026-09-30.md). Execução real no iPhone de fabio: individual teve três eventos, grupo zero; opção de gesto manteve três eventos mas aumentou custo/descartes numa execução curta. Agora há PNG reais por DVT, sem runner ou lentes. Capturas de grupo mostram mistura de braço/perna do colega enquanto o atleta central fica “Em foco”; não confundir com troca temporal de identidade comprovada. O alvo central parece agachar, embora colegas façam afundos; anotar antes de interpretar zero. Histórico idêntico após testes, app reiniciado sem flags QA. Próximo passo: associar imagens a PTS, revisar pose/confianças e rotular ciclos. Sem retreinamento/alteração de código/modelos nesta continuação; M2, gestos positivos, câmera real e beta pendentes.

**Captura com fonte gravada:** [modo DEBUG e evidência](qa-recorded-camera-2026-09-30.md). Dois clipes Pexels foram copiados para `Documents/QAPrivateClips` do iPhone de fabio, sem apagar originais. `--qa-recorded-camera` fornece quadros locais à fila ao vivo e mostra a fonte na tela; não abre lentes nem persiste treino. O teste UI verifica aviso/seleção/Parar e gera capturas; a política de Histórico tem teste separado. O bloqueio inicial por telefone travado foi superado pelo usuário; runner segue sem perfil, mas execução por CLI e capturas DVT funcionaram. Esse modo não valida câmera pareada, gestos à distância ou M2.

**Último incremento — gestos aprovados:** [implementação, QA e próximos ensaios](qa-hand-gestures-2026-09-30.md). Opção nas configurações avançadas, desligada por padrão, somente ao vivo: palma aberta/punho fechado acima do ombro por 2 s, progresso e confirmação falada. Trinta segundos para seleção inicial; depois da perda, gesto não troca atleta. Dois defeitos encontrados por Astra receberam regressões (rival cortado e perda entre leituras de mão). Pipeline usa MediaPipe Gesture Recognizer versão 1 local, sem retreinar. Conferir relatório de execução/instalação; teste de UI não é câmera física nem gate de box.

**Branch de trabalho:** `feat/m2-android-a0`
**Objetivo imediato:** tornar a seleção de uma pessoa em vídeo de grupo mensurável e segura antes de ampliar exercícios, distribuir beta ou iniciar Android.

**Solicitação anterior — teste no box:** [investigação de 30/09](box-investigation-2026-09-30.md). Usuário precisa iniciar à distância e manter um atleta numa sala com várias pessoas. Duas sessões longas do Histórico tiveram zero eventos e predominância de reseleção; dados privados inspecionados, sem anotação completa ou causa por quadro adjudicada. Detector/rastreador separados + ROI ainda exigem desenho aprovado. Gesto foi aprovado e implementado posteriormente como experimento, não solução de identidade. Revisão Astra reforçou recuperar alvo anterior sem substituição por colega. Não confundir pareamento com espelhamento, replay com reanálise ou mais vídeos com retreinamento.

**Incremento de 30/09:** [relatório da demonstração](demo-box-2026-09-30.md). Há avaliador de clipe completo em `tools/evaluate-complete-clip.mjs`, tema temporário escuro/ciano, Lite/Full e modos experimentais recolhidos, espera de 3 s após seleção ao vivo e núcleo `PushUpCounter` **não integrado**. O teste sintético do contador de flexão não aprova flexão na UI. Primeiro obter rótulos privados completos e repetir o pipeline; M0/M2 não passaram. O modo de câmera preto em pareamento permanece questão separada. Para reconstruir o workspace após novos arquivos, executar `xcodegen generate` e `pod install --deployment`.

**Correção mais recente — 29/09:** [relatório, causas, testes e limites](qa-tracking-correction-2026-09-29.md). A truncagem Vision em quatro poses foi removida; o rastreador conserva contexto temporário dos rivais e abstém-se em associações ambíguas; ausência breve do ângulo não descarta o ciclo se a identidade continua confirmada. A revisão Astra reproduziu dois defeitos da primeira implementação e confirmou suas correções. Build físico e 66 testes de núcleo + 5 UI passaram; 15 testes Node passaram. No build final instalado no iPhone, o caso original passou nos nove quadros rotulados, com 306/316 decisões `selected` e três eventos automáticos. **Não é validação geral de identidade/contagem, nem de MediaPipe.** Ativar Vision antes de reimportar para reproduzir o ensaio. A automação antiga está pausada e a sessão manual encerrada; a restrição histórica abaixo de não reinstalar não se aplica aos ensaios posteriores autorizados.

**Achado crítico de 26/09:** o reensaio manual com Apple Vision confirmou troca do aluno de tênis branco pelo colega à direita aos **1,1 s**, após ausência curta do alvo entre os candidatos. Veja [evidência e limites](monitoring-imports.md#reensaio-vision--troca-de-pessoa-confirmada-2609). Decisão `selected` não comprova identidade; M2 permanece reprovado mesmo quando a cobertura aparente é alta. Foi feita somente investigação/documentação, sem alterar o app durante os testes. Próxima regressão deve cobrir essa troca e a distinção entre pose detectada e elegibilidade de seleção, que hoje pode esconder alunos agachados.

**Sessão de testes do proprietário em 26/09:** [monitoramento de importações](monitoring-imports.md). O build Debug com `--qa-monitor-imports` registra início, falhas/recusas e relatórios separados por escolha, em `Documents/QAMonitoring`, somente localmente. Uma automação desta conversa acompanha os JSON a cada 5 minutos durante o dia. Não interromper a sessão do usuário para reinstalar/trocar modelo. Xcode está no workspace atual e no destino físico; interface do Device Hub continua indisponível por timeout, mas o contêiner do iPhone é acessível. Preparação passou em build físico e 54 testes de núcleo; clipe de referência comprovou registro de 743 quadros/4 eventos, sem validar acurácia.

**Atualização mais recente (25/09, vídeo de tela do proprietário):** [pôster e perda do alvo](qa-poster-and-target-2026-09-25.md). O alvo agora usa geometria do tronco quando disponível; seleção em vídeo importado de grupo filtra automaticamente poses sem joelho analisável em uma janela temporal. No iPhone físico, o pôster observado foi recusado, a cobertura do homem de preto subiu de 21 para 428/866 quadros e o clipe da atleta à direita manteve 692/693 quadros e 2 eventos. Testes: 54 núcleo + 5 UI. **Não tratar isto como prova de identidade, anti-foto universal ou precisão de contagem**. O próximo passo é rotular trechos de cruzamento e usar sessão independente como aceitação.

**Novo ensaio do Histórico em 25/09:** [sete vídeos gravados hoje, causa reproduzida e limite da correção](qa-iphone-history-noise-2026-09-25.md). O rastreador agora rejeita saltos espaciais incompatíveis com o intervalo entre quadros; o app oferece análise quadro a quadro para vídeos de grupo como opção, pois ela ajudou um clipe de duas pessoas mas piorou a continuidade em outro. Suíte atual: **50 testes de núcleo + 5 UI aprovados**. O app atualizado foi instalado e iniciado no iPhone físico; o índice do Histórico permaneceu idêntico. M2 segue **não validado**. Vídeos e relatórios detalhados ficam privados, fora do Git.

**Nota de 25/09, incremento posterior:** seleção offline corrigida, rastreador com aparência cromática temporária e confirmação em dois quadros após lacuna; a revisão Astra corrigiu a confirmação em 30/60 fps e impediu que um rival rejeitado voltasse sem assinatura. Cor temporária não é codificada no JSON de QA. `docs/qa-single-target-2026-09-25.md` é o relatório mais recente. A suíte atual passou com **49 testes de núcleo + 5 UI no simulador**. O gate M2 segue reprovado sem anotações humanas. Vídeo privado de diagnóstico: `~/Library/Application Support/RitmoVis/qa-private/RitmoVis-M2-evidencia-privada-20260925.mp4`; contém pessoas reais, não publicar. O iPhone físico conectado teve o índice do Histórico lido sem remoção de dados e o clipe mais recente copiado para `qa-private/iphone-history-20260925-latest.mov`; os seis eventos registrados pelo app ainda não foram conferidos por humano. Não use esses dados para ajuste e depois como holdout.

## Leitura mínima, nesta ordem

1. Este arquivo.
2. [Histórico do iPhone e ruído](qa-iphone-history-noise-2026-09-25.md), [corpus pessoal e QA de 25/09](qa-private-videos-2026-09-25.md), depois [QA de seleção de grupo de 24/09](qa-group-selection-2026-09-24.md).
3. [Roadmap](../roadmap.md) — gates e ordem dos marcos.
4. [Protocolo M0](m0-annotation-protocol.md) e [fluxo de vídeos](video-qa-workflow.md) — como obter evidência real.
5. [Decisões](decisions.md) e [arquitetura](architecture.md) — antes de alterar detector, privacidade ou contrato entre plataformas.

## Estado verificável

| Área | Implementado | Evidência / limite |
|---|---|---|
| iOS | SwiftUI, câmera frontal/traseira, tela de treino, gravação opcional, histórico, replay e importação Arquivos/Fotos | app de desenvolvimento instalado no **iPhone de fabio**; câmera com pareamento ainda é problema ambiental aberto |
| Uma pessoa | MediaPipe Lite/Full, máquina de estados de agachamento e avaliação de eventos | clipe local de QA contou 4 ciclos; não há corpus anotado suficiente para alegação de precisão |
| Grupo / M2 | múltiplas poses, seleção explícita, `TargetTracker` com geometria + aparência temporária, abstenção e `OfflineTargetAnalyzer` | reensaio de cinco seleções privadas no simulador; cobertura melhorou em algumas e não em outras; ainda não há verdade humana de ID; M2 **não passou** |
| Contrato iOS/Android | `fixtures/tracking-v1-synthetic.json` e teste Swift | sintético; Android ainda não foi criado/testado |
| QA automatizado | 123 testes de núcleo + 10 UI + 8 hospedados + 29 Node | 141/141 Xcode no simulador em 05/10, zero falhas/skips; 123/123 Swift e 29/29 Node. Build físico/CLI e Release iOS para simulador passaram; runner UI físico não repetido após renovação. Diagnóstico privado preserva poses rejeitadas, sem mudar tracking |

## O que não afirmar

- Não dizer que o app avalia técnica correta, segurança ou previne lesão.
- Não dizer que reconhece identidade de aluno, professor ou visitante. Caixas e índices são observações por quadro.
- Não dizer que M2, câmera pareada, beta iOS ou Android estão validados.
- Não converter 3 eventos no clipe Pexels em precisão, recall ou desempenho geral.
- Não colocar vídeos, gravações de pessoas, poses extraídas, pesos `.task`, renders, Pods, credenciais ou relatórios privados no Git.

## Arquitetura atual resumida

```text
vídeo/câmera → PoseDetector → candidatos normalizados + poses
    → TargetTracker (somente seleção explícita) → SquatCounter
    → eventos, overlay, replay/histórico

vídeo de grupo importado:
primeiro passe → cache de poses → toque no alvo → OfflineTargetAnalyzer
    → mesmo AVPlayer, contagem apenas a partir do quadro escolhido
```

`PoseDetector` usa MediaPipe na câmera ao vivo. Para importação de grupo há uma opção experimental de Apple Vision. Na comparação pareada 7209 de 05/10 Vision teve 421 decisões selecionadas/37 incertas/zero reseleção e sete eventos não validados, contra quatro variantes MediaPipe com perdas; prioridade de anotação, não gate de qualidade/identidade. IMAGE independente não resolveu MediaPipe. A opção não deve alterar a câmera ao vivo. A calibração opcional de quadro em pé é `standing-reference-v1`; ela é por seleção e não é avaliação de forma.

## Próxima sequência de trabalho — não pular

1. **M0:** anotar manualmente 50+ ciclos autorizados, separar ajuste de aceitação e executar o avaliador. Rodar câmera 10 min no iPhone quando a condição de pareamento estiver definida.
2. **M2:** ampliar as nove marcações da regressão de 29/09 para os clipes completos, conforme [esquema M2](m2-annotation-schema.md), e obter sessão independente com ao menos dois cenários consentidos de cruzamento. Medir cobertura, troca de identidade, TP/FP/FN e períodos de abstenção. Não usar o corpus de ajuste como holdout nem estados `selected` como verdade humana. Repetir MediaPipe no último patch antes de alegar melhoria nesse backend.
3. Runner UI físico não foi repetido após renovar perfil/confiança: distinguir esse gate da execução física por CLI que passou em 05/10. Não alterar contas, senhas ou permissões sem o proprietário.
4. Só depois discutir promoção de Vision/calibração, beta iOS, novos exercícios ou Android A0.

## Comandos reproduzíveis

```sh
cd ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
xcodegen generate
pod install --deployment
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -workspace SquatCounter.xcworkspace -scheme SquatCounter \
  -configuration Debug -destination 'platform=iOS Simulator,id=BCE5929A-8306-4680-929A-58D870392F47' \
  -derivedDataPath /tmp/ritmovis-qa test CODE_SIGNING_ALLOWED=NO
```

Para o dispositivo, use o UDID e caminhos já registrados em `docs/qa-group-selection-2026-09-24.md`; não trate uma compilação como teste físico. Regenerar com XcodeGen antes de usar o workspace se `project.yml` mudar.

## Dados e localização

- Repositório: `git@github.com:fabioffigueiredo/RitmoVis.git`.
- Relatórios privados: `~/Library/Application Support/RitmoVis/qa-private/`.
- O app legado fica separado do bundle de desenvolvimento `com.fabiofigueiredo.ritmovis.dev`.
- Recursos Pexels ficam fora do Git e servem somente para QA/editorial sob as condições registradas em `assets-and-licenses.md`.

## Histórico e dívida relevante

Leia [histórico do projeto](project-history.md). Dívidas abertas: métrica `noPoseFrames` mistura ausência de alvo selecionado e ausência de pessoa e conserva o primeiro passe após seleção offline; originais MOV 4K/10-bit e desempenho longo ainda não foram testados após suporte a rotação; avisos de APIs AVFoundation obsoletas; captura preta quando o iPhone está pareado; runner de UI físico não reverificado após renovação; nome/marca RitmoVis não verificados.
