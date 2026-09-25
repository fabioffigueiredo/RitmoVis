# RitmoVis

RitmoVis é o nome provisório de um MVP para iPhone que estima a pose no aparelho e conta ciclos de agachamento. O contador usa uma regra de estados sobre articulações estimadas; não mede qualidade, segurança ou correção da execução.

Este repositório extrai o código dos protótipos `squat-counter-ios` e `squat-counter-video` em 2026-09-23. Os originais permanecem no projeto de origem. A nomenclatura interna `SquatCounter` ainda aparece em alvos, módulos e composições para preservar a implementação verificável.

## Estrutura

- `ios/`: app SwiftUI, núcleo de contagem, testes e configuração XcodeGen/CocoaPods.
- `video/`: código das peças editoriais Remotion em 16:9 e 4:5. Não inclui vídeos, gravações de aparelho ou imagens derivadas. As composições não renderizam sem os arquivos descritos em [assets](docs/assets-and-licenses.md).
- `docs/`: arquitetura, status de QA e proveniência.
- `ios/Fixtures/`: exemplo **sintético** do formato de anotação para avaliar repetições; nenhum dado pessoal.

## Preparar o app

Requisitos: macOS com Xcode completo selecionado (`xcode-select` ou `DEVELOPER_DIR`), Swift 6, XcodeGen 2.38+, CocoaPods e acesso à internet para dependências. O alvo iOS mínimo é 17. Para testar a câmera, use iPhone físico.

```sh
cd ios
./Scripts/download_models.sh
xcodegen generate
pod install
open SquatCounter.xcworkspace
```

O script busca os modelos oficiais MediaPipe e exige os SHA-256 observados na extração. O endpoint oficial contém `latest`; se o fornecedor o alterar, o script falha e exige revisão consciente do checksum. O clipe de demonstração Pexels é opcional e não está neste repositório: o botão mostra uma mensagem de ausência até que um arquivo autorizado seja instalado com o nome esperado. Confira [assets](docs/assets-and-licenses.md).

Para compilar no simulador sem assinatura:

```sh
cd ios
xcodebuild -workspace SquatCounter.xcworkspace -scheme SquatCounter -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
swift test
```

Para aparelho físico, confirme sua equipe e um bundle identifier único em `project.yml` antes de gerar novamente. O identificador atual `com.fabiofigueiredo.ritmovis.dev` é de desenvolvimento e está instalado separadamente do protótipo antigo no iPhone de fabio. A câmera não é validável no simulador.

Para analisar vídeos enviados por outras pessoas, salve-os em Arquivos ou Fotos no iPhone e abra **Treino → Analisar vídeo recebido**. A análise fica no aparelho, seguida de replay com contagem/caixas detectadas; o clipe não entra no Histórico. **Se mais de uma pessoa for detectada em qualquer quadro analisado, as contagens provisórias são descartadas**. Toque em **Selecionar** sobre o aluno no replay para reprocessar a partir daquele instante; rastreamento em grupo ainda é experimental e pode se abster. Uma detecção falha ainda pode não reconhecer outra pessoa presente. Use o [protocolo de QA de vídeos](docs/video-qa-workflow.md) e obtenha consentimento para qualquer gravação de terceiros.

## Começar a validação M0

O núcleo inclui agora um avaliador de repetições anotadas manualmente. Ele reporta TP/FP/FN, eventos duplicados ou perdidos e falsos positivos durante tentativas incompletas; o exemplo é sintético e **não** constitui resultado de desempenho do app:

```sh
cd ios
swift run ritmovis-eval Fixtures/evaluation-synthetic.example.json
```

Antes de usar gravações reais, siga o [protocolo de anotação](docs/m0-annotation-protocol.md). A coleta de 50 repetições e o ensaio de 10 minutos no iPhone continuam pendentes.

## Preparar o vídeo editorial

O código Remotion pode ser instalado com `cd video && npm ci`. Após colocar mídia autorizada nos nomes listados em [assets](docs/assets-and-licenses.md), use `npm run studio`, `npm run render` ou `npm run still` para 16:9; `npm run render:social` e `npm run still:social` geram a variação 4:5. Os outputs locais ficam em `video/out/` e não entram no Git. Uma peça foi renderizada e aguarda aprovação no projeto editorial de origem; veja [publicação](docs/publication.md).

## Situação

Em 24/09/2026, a suíte do simulador passou 44 testes (39 de núcleo e 5 de UI). No iPhone físico, o experimento de grupo contou três eventos com Vision e calibração explícita, mas perdeu o alvo antes do fim; isso **não** valida M2. Veja o [relatório de grupo](docs/qa-group-selection-2026-09-24.md), a [situação de QA](docs/qa-status.md) e o [handoff de desenvolvimento](docs/claude-handoff.md). Não há evidência de precisão geral, robustez entre pessoas/ângulos nem avaliação de técnica. O app processa localmente, grava apenas se a opção for ativada e importa somente um vídeo selecionado pelo usuário.

## Próximos passos

Ver [roadmap](roadmap.md), [handoff para continuidade](docs/claude-handoff.md), [histórico](docs/project-history.md), [decisões](docs/decisions.md) e [publicação](docs/publication.md). Nenhuma distribuição, publicação ou licença própria foi definida nesta extração.
