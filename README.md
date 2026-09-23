# RitmoVis

RitmoVis é o nome provisório de um MVP para iPhone que estima a pose no aparelho e conta ciclos de agachamento. O contador usa uma regra de estados sobre articulações estimadas; não mede qualidade, segurança ou correção da execução.

Este repositório extrai o código dos protótipos `squat-counter-ios` e `squat-counter-video` em 2026-09-23. Os originais permanecem no projeto de origem. A nomenclatura interna `SquatCounter` ainda aparece em alvos, módulos e composições para preservar a implementação verificável.

## Estrutura

- `ios/`: app SwiftUI, núcleo de contagem, testes e configuração XcodeGen/CocoaPods.
- `video/`: código de um rascunho Remotion. Não inclui vídeos, gravações de aparelho ou imagens derivadas. A composição não renderiza sem os arquivos descritos em [assets](docs/assets-and-licenses.md).
- `docs/`: arquitetura, status de QA e proveniência.

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

Para aparelho físico, defina sua equipe e um bundle identifier único nas configurações do projeto gerado ou em `project.yml` antes de gerar novamente. O identificador `com.example.ritmovis` é apenas um placeholder. A câmera não é validável no simulador.

## Preparar o rascunho de vídeo

O código Remotion pode ser instalado com `cd video && npm ci`. Após colocar mídia autorizada nos nomes listados em [assets](docs/assets-and-licenses.md), use `npm run studio`, `npm run render` ou `npm run still` para 16:9; `npm run render:social` e `npm run still:social` geram a variação 4:5. Os outputs locais ficam em `video/out/` e não entram no Git. As composições descrevem um ensaio específico e exigem revisão do conteúdo antes de distribuição.

## Situação

O protótipo original teve testes de núcleo/UI e ensaios limitados em iPhone 15 em setembro de 2026; veja [status de QA](docs/qa-status.md) para a separação entre resultados históricos e verificações feitas nesta extração. Não há evidência de precisão geral, robustez entre pessoas/ângulos nem avaliação de técnica. O app processa localmente, grava apenas se a opção for ativada e importa somente um vídeo selecionado pelo usuário. Consulte o código e o [mapa de arquitetura](docs/architecture.md) para os detalhes.

## Próximos passos

Ver [roadmap](roadmap.md). Nenhuma distribuição, publicação ou licença própria foi definida nesta extração.
