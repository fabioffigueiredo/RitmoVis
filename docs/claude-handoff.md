# Handoff para Claude — RitmoVis

**Atualizado em:** 26/09/2026

**Branch de trabalho:** `feat/m2-android-a0`
**Objetivo imediato:** tornar a seleção de uma pessoa em vídeo de grupo mensurável e segura antes de ampliar exercícios, distribuir beta ou iniciar Android.

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
| QA automatizado | 49 testes de núcleo + 5 UI | 54/54 no simulador em 25/09; Vision no simulador não retornou quadros úteis, então esse teste UI usa MediaPipe |

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

`PoseDetector` usa MediaPipe na câmera ao vivo. Para importação de grupo há uma opção experimental de Apple Vision, porque funcionou melhor no único clipe comparado. A opção não deve alterar a câmera ao vivo. A calibração opcional de quadro em pé é `standing-reference-v1`; ela é por seleção e não é avaliação de forma.

## Próxima sequência de trabalho — não pular

1. **M0:** anotar manualmente 50+ ciclos autorizados, separar ajuste de aceitação e executar o avaliador. Rodar câmera 10 min no iPhone quando a condição de pareamento estiver definida.
2. **M2:** anotar os novos vídeos pessoais conforme [esquema M2](m2-annotation-schema.md) (alvo, ciclos, oclusões, professor/visitantes/pôster) e ao menos dois cenários consentidos de cruzamento. Medir cobertura, troca de identidade, TP/FP/FN e períodos de abstenção. Não ajustar limiar com base em um clipe ou em rótulos inferidos pelo detector.
3. Corrigir/reproduzir o bloqueio de runner UI físico somente se houver conta/perfil Apple válidos. Não alterar contas, senhas ou permissões sem o proprietário.
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

Leia [histórico do projeto](project-history.md). Dívidas abertas: métrica `noPoseFrames` mistura ausência de alvo selecionado e ausência de pessoa; originais MOV 4K/10-bit e desempenho longo ainda não foram testados após suporte a rotação; avisos de APIs AVFoundation obsoletas; captura preta quando o iPhone está pareado; runner de UI físico sem perfil; nome/marca RitmoVis não verificados.
