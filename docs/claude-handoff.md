# Handoff para Claude — RitmoVis

**Atualizado em:** 25/09/2026

**Branch de trabalho:** `feat/m2-android-a0`
**Objetivo imediato:** tornar a seleção de uma pessoa em vídeo de grupo mensurável e segura antes de ampliar exercícios, distribuir beta ou iniciar Android.

## Leitura mínima, nesta ordem

1. Este arquivo.
2. [QA de seleção de grupo](qa-group-selection-2026-09-24.md) — única fonte para os resultados mais recentes de M2.
3. [Roadmap](../roadmap.md) — gates e ordem dos marcos.
4. [Protocolo M0](m0-annotation-protocol.md) e [fluxo de vídeos](video-qa-workflow.md) — como obter evidência real.
5. [Decisões](decisions.md) e [arquitetura](architecture.md) — antes de alterar detector, privacidade ou contrato entre plataformas.

## Estado verificável

| Área | Implementado | Evidência / limite |
|---|---|---|
| iOS | SwiftUI, câmera frontal/traseira, tela de treino, gravação opcional, histórico, replay e importação Arquivos/Fotos | app de desenvolvimento instalado no **iPhone de fabio**; câmera com pareamento ainda é problema ambiental aberto |
| Uma pessoa | MediaPipe Lite/Full, máquina de estados de agachamento e avaliação de eventos | clipe local de QA contou 4 ciclos; não há corpus anotado suficiente para alegação de precisão |
| Grupo / M2 | múltiplas poses, seleção explícita, `TargetTracker`, abstenção e `OfflineTargetAnalyzer` | Vision + calibração contou 3 eventos no clipe específico, mas perdeu alvo após 12,52 s; M2 **não passou** |
| Contrato iOS/Android | `fixtures/tracking-v1-synthetic.json` e teste Swift | sintético; Android ainda não foi criado/testado |
| QA automatizado | 39 testes de núcleo + 5 UI | 44/44 no simulador em 24/09; Vision no simulador não retornou quadros úteis, então esse teste UI usa MediaPipe |

## O que não afirmar

- Não dizer que o app avalia técnica correta, segurança ou previne lesão.
- Não dizer que reconhece identidade de aluno, professor ou visitante. Caixas e índices são observações por quadro.
- Não dizer que M2, câmera pareada, beta iOS ou Android estão validados.
- Não converter 3 eventos no clipe Pexels em precisão, recall ou desempenho geral.
- Não colocar vídeos, gravações de pessoas, pesos `.task`, renders, Pods, credenciais ou relatórios privados no Git.

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
2. **M2:** anotar o clipe de grupo já usado (alvo, ciclos, oclusões, professor/visitantes) e ao menos dois cenários consentidos de cruzamento. Medir cobertura, troca de identidade, TP/FP/FN e períodos de abstenção. Não ajustar limiar com base em apenas um clipe.
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

Leia [histórico do projeto](project-history.md). Dívidas abertas: métrica `noPoseFrames` mistura ausência de alvo selecionado e ausência de pessoa; vídeo vertical/transformado é rejeitado; avisos de APIs AVFoundation obsoletas; captura preta quando o iPhone está pareado; runner de UI físico sem perfil; nome/marca RitmoVis não verificados.
