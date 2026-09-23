# Instruções de trabalho — RitmoVis

- Mantenha o escopo do produto como contagem experimental de ciclos de agachamento. Não descreva o resultado como correção de forma, segurança ou orientação de saúde.
- `ios/project.yml` é a fonte da configuração Xcode; gere o `.xcodeproj` com XcodeGen. Abra o `.xcworkspace` criado pelo CocoaPods.
- `ios/Package.swift` contém somente o núcleo testável em Swift Package Manager. A UI e MediaPipe são compilados pelo workspace.
- Não versione modelos `.task`, clipes, capturas pessoais, outputs de render, Pods, node_modules, artefatos de build ou credenciais de assinatura.
- Ao mudar thresholds/estado do contador, atualize testes relevantes e registre dispositivo, modelo, câmera, iluminação, frames e contagens esperadas/detectadas antes de afirmar melhoria.
- Os recursos necessários, as fontes e as lacunas de autorização estão em `docs/assets-and-licenses.md`. Não presuma direito de redistribuição de mídia externa.
- Diferencie sempre resultados herdados do protótipo e resultados repetidos no repositório independente em `docs/qa-status.md`.
- Leia `roadmap.md` antes de ampliar escopo: M0 valida uma pessoa; M2 seleciona uma pessoa entre várias; M4 testa contagem simultânea de 2–4 atletas. Não trate `numPoses > 1` como identidade estável.
- Leia `docs/decisions.md` e `docs/publication.md` antes de mudar modelo, fluxo de dados ou alegações públicas. A peça 4:5 já foi renderizada fora deste repositório e aguarda aprovação; não publique automaticamente.
