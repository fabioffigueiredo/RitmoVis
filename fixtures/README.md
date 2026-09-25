# Contrato de eventos para iOS e Android

`tracking-v1-synthetic.json` é um fixture **sintético** de comportamento; não mede inferência nem precisão em pessoas. Ambas as implementações devem ler o mesmo JSON e emitir a decisão e a contagem esperadas após cada quadro. Não grave mídia ou identificadores pessoais aqui.

- `schemaVersion`: inteiro; mudanças incompatíveis exigem nova versão e fixture novo.
- `timeSeconds`: PTS monotônico da sessão, não horário do relógio. Câmera e arquivo importado devem preservar ordem.
- `observations`: poses de um quadro; `index` é posição transitória na lista, não identidade. Coordenadas e dimensões são normalizadas em 0–1 no quadro **de análise**; espelhamento é responsabilidade do adaptador de UI.
- `confidence` e `kneeAngle`: números fornecidos pelo adaptador/fixture; o ângulo não é avaliação de técnica. Em arquivos reais, registre pesos/modelo usados e proveniência fora do Git.
- `expectedTracking`: `noSelection`, `selected`, `uncertain` ou `reselectionRequired`. `expectedIndex` só existe para `selected` e refere-se ao quadro atual.
- `selectAfterIndex`: ação explícita do usuário **depois** desse quadro; nunca conta uma repetição nesse instante. O próximo quadro ainda precisa mostrar a pessoa em pé para iniciar um novo ciclo.
- `expectedCount`: repetições completas acumuladas. `uncertain` invalida ciclo parcial e preserva o total. Após cruzamento ambíguo, `reselectionRequired` permanece até novo toque; não se escolhe automaticamente o único candidato que restou.

O teste Swift está em `ios/Tests/SquatCounterCoreTests/TrackingFixtureTests.swift`. Android A0 deve reproduzir exatamente essas decisões em Kotlin antes de integrar CameraX/MediaPipe. Um fixture de vídeo real não substitui a avaliação por anotações independentes descrita em `docs/m0-annotation-protocol.md` e `roadmap.md`.
