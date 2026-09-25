# M2 no iPhone 15 físico — clipe 7209, Lite versus Full

**Data:** 25/09/2026. **Build:** branch `feat/m2-android-a0`, commit `e35a10f`, instalado em `iPhone de fabio` (iPhone 15) via Xcode/devicectl. O índice do Histórico foi copiado antes e após a instalação e comparado byte a byte: não mudou. O aparelho estava pareado e desbloqueado. Não testamos câmera ao vivo, que teve prévia preta em sessões anteriores de pareamento; estes testes usaram arquivo importado.

**Entrada:** cópia privada H.264/8-bit, 720p, 473 quadros (~15,77 s) do `IMG_7209.MOV` fornecido pelo proprietário, duas pessoas agachando. Seleção experimental automática da candidata próxima a `(x=0,77; y=0,60)` no primeiro quadro; isso reproduz o toque, mas **não** constitui rótulo humano de identidade. O clipe foi copiado apenas para `Documents` do contêiner do app; originais preservados. SHA-256 do original e proveniência estão em [corpus privado](qa-private-videos-2026-09-25.md).

| Métrica observada | Lite | Full |
|---|---:|---:|
| Quadros processados | 473 | 473 |
| Quadros com alvo selecionado | 225 (47,6%) | 216 (45,7%) |
| Quadros incertos | 39 | 27 |
| Quadros exigindo reseleção | 209 | 230 |
| Quadros sem pessoa detectada | 2 | 2 |
| Eventos automáticos | 1 | 1 |
| Inferência média / p95 | 28,7 / 38,1 ms | 40,2 / 48,5 ms |

**Veredito deste caso:** ambos os modelos processaram o vídeo no iPhone, mas o rastreador deixou de acompanhar o aluno em mais da metade dos quadros. A inspeção visual mostra movimento continuando enquanto o app pede reseleção. Portanto **M2 falhou no requisito de continuidade para este clipe**. Um evento não é precisão/recall: não existe anotação independente de cada repetição, não medimos troca de identidade e não avaliamos técnica. A diferença Lite/Full nesta única entrada não estabelece qual é melhor no produto; faltam diversidade, energia, FPS sustentado, holdout e outros aparelhos. Inferência por quadro durante análise de arquivo não é latência total de câmera ao vivo.

Relatórios completos privados (com linha do tempo e sem assinatura cromática serializada): `~/Library/Application Support/RitmoVis/qa-private/7209-iphone15-physical-20260925.json` e `7209-iphone15-physical-full-20260925.json`. Vídeo comparativo privado de 31,5 s: `~/Library/Application Support/RitmoVis/qa-private/RitmoVis-M2-comparacao-iPhone-fisico-Lite-Full-20260925.mp4`. Ele mostra **vídeo original + overlays derivados do traço real exportado pelo app no iPhone físico**, primeiro Lite e depois Full; **não é gravação da tela física**. A revisão visual de quadros e decodificação integral passou. Pessoas identificáveis aparecem; não publicar nem compartilhar sem autorização.

O @Computador foi solicitado para abrir o Device Hub e ver a tela, mas a interface retornou `timeoutReached` repetidamente. O processo QA foi iniciado no iPhone por `devicectl` e o relatório foi recuperado do contêiner; **a interface física/replay não foi confirmada visualmente por esta sessão**. Não inferir isso do JSON. O próximo teste deve envolver captura nativa da tela ou confirmação presencial, além de anotação humana por duas pessoas. Ver [protocolo de gravação](recording-protocol-single-target.md) e [roadmap](../roadmap.md).
