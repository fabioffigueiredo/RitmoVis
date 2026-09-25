# Corpus privado recebido em 25/09/2026 — diagnóstico, não acurácia

Os quatro arquivos foram fornecidos pelo proprietário para teste e possível treinamento. Originais, transcodificações, quadros, poses e relatórios individuais permanecem em `~/Library/Application Support/RitmoVis/qa-private/new-videos-wtUpM1/`, fora do Git. Não presumir autorização das outras pessoas filmadas para distribuição ou treinamento comercial. O manifesto abaixo contém somente metadados e hashes para identificar as versões.

| Original | Duração | SHA-256 | Cenário observado |
|---|---:|---|---|
| IMG_7209.MOV | 15,765 s | `37901f533a943dab72fb864d84cb3958012b76f738925e4174003574e24bf24f` | Dois atletas agacham e mudam de orientação; pôster de pessoa na parede gera uma detecção espúria no Apple Vision. |
| IMG_7210.MOV | 1038,83 s | `2ca8abb97a29052bc2c079c7d4d032f530ec1960eb0a128740ee41a0eb2cce0c` | Sessão longa com atletas, intervalos, barra e instruções; amostras de 12 s em 60, 240, 480, 720 e 960 s. |
| IMG_7211.MOV | 10,465 s | `c74605d979ac54c07fe49b7a3625cf3ca3f835f4a8e194d59e88d6ff6e5c5809` | Turma com vários praticantes e pessoa passando em primeiro plano. |
| IMG_7212.MOV | 10,537 s | `8087dfffa19334478fbd8a8f0e036dc37bedd713a4dff74e7032068c68dfff03` | Turma ampla, pessoas em profundidades diferentes e passagem à frente. |

## Preparação e execução

- Os originais são 4K/30 fps com rotação de apresentação e vídeo de 10 bits. Para a bateria no **simulador iPhone 15/iOS 27**, foram criados oito trechos privados 720p, H.264/8 bits, sem áudio. Isto testa a lógica sobre o conteúdo, mas **não** o desempenho dos originais 4K nem a câmera do iPhone físico.
- `tools/vision-poses.swift` extrai amostras esparsas em JSONL local, aplicando a rotação do arquivo antes do Apple Vision. As amostras são material de anotação, não rótulos verdadeiros. O primeiro ensaio sem aplicar a rotação foi descartado por orientação incorreta.
- O app DEBUG aceita `--qa-private-clip=<arquivo>` somente no seu contêiner Documents. Os relatórios `qa-clip-diagnostics.json`, `qa-clip-failure.json` e `qa-launch.json` são gerados no contêiner. Sucesso antigo agora é apagado no início de cada execução QA, para não ser confundido com resultado novo.
- O leitor AVFoundation foi atualizado para aceitar quadros verticais e aplicar a matriz de rotação embutida. Um fixture privado 8-bit com matriz de 90° foi processado no simulador: 240/240 quadros, 0 descartados, imagem de análise 406×720. Isso não prova decodificação dos MOV 4K no aparelho físico.
- Apple Vision no simulador falhou ao inicializar `VNDetectHumanBodyPoseRequest` (erro `Unable to setup request...`); portanto a bateria completa do simulador abaixo usa **MediaPipe Lite**, não Apple Vision. A ferramenta Swift no Mac consegue extrair amostras Vision, mas não substitui o teste no iPhone.

| Trecho | Quadros processados | Com 2+ candidatos | Máximo de candidatos | Descartados | Contagens sem seleção |
|---|---:|---:|---:|---:|---:|
| 7209 completo | 473 | 351 | 3 | 0 | 0 |
| 7211 completo | 314 | 314 | 4 | 0 | 0 |
| 7212 completo | 316 | 291 | 4 | 0 | 0 |
| 7210, 60 s | 359 | 345 | 4 | 0 | 0 |
| 7210, 240 s | 359 | 140 | 4 | 0 | 0 |
| 7210, 480 s | 360 | 279 | 4 | 0 | 0 |
| 7210, 720 s | 360 | 89 | 3 | 0 | 0 |
| 7210, 960 s | 360 | 172 | 3 | 0 | 0 |

`noPoseFrames` no relatório atual soma quadros sem pose selecionada e **não** significa que nenhuma pessoa foi detectada. Ao selecionar automaticamente a candidata mais central do primeiro quadro, o rastreador cobriu apenas 57/473 quadros no 7209, 1/314 no 7211, 49/316 no 7212, 1/359 no trecho 60 s e 152/359 no trecho 240 s. Nenhum desses ensaios contou repetição. Essa seleção por centro é um artifício de QA e pode nem escolher o atleta pretendido. No 7209, aos 1,9 s, duas caixas sobrepostas próximas do alvo tornaram a associação ambígua; a abstenção evitou crédito a outra pessoa, mas a reseleção passou a ser necessária. Um segundo ensaio de QA escolheu o atleta à direita em (x=0,77, y=0,60): 62/473 quadros acompanhados e **um evento em 1,67 s**, antes de exigir reseleção. O vídeo segue além desse ponto; um evento detectado não é avaliação de precisão. **Cobertura insuficiente; M2 segue reprovado.**

## O que o material permite — e o que ainda falta para treinar

Os vídeos já compõem um corpus privado de casos difíceis: múltiplas poses, oclusões, estáticos parecidos com pessoa, professor/transeuntes e transições exercício/descanso. Eles **não** fornecem automaticamente rótulos de identidade, papel, repetição completa ou execução correta. Quatro vídeos da mesma sessão/ambiente não bastam para afirmar generalização. Não ajustar limiar usando os mesmos quadros como treino e prova de acerto.

Próximo conjunto de anotações: para cada trecho, definir pessoa(s) alvo por intervalo, caixas/ID temporário em quadros de referência, períodos de oclusão/crossing, papel `aluno/professor/visitante/estático/incerto`, início/fim de cada repetição e tentativas incompletas. Confirmar consentimento/uso de cada pessoa. Seguir o [esquema de anotação M2](m2-annotation-schema.md). Separar **por gravação/sessão**, não por quadros aleatórios, conjuntos de ajuste e aceitação. Só então treinar ou calibrar um classificador posterior aos landmarks/tracker, comparar com MediaPipe Lite/Full e Apple Vision no hardware adequado, medir trocas de ID, falsos créditos, precisão/recall e cobertura. Não retreinar pesos do MediaPipe ou declarar “ruído removido” sem essa referência humana e validação independente.

## Falhas acionáveis

1. A seleção de grupo ainda depende de toque/reseleção; não há ID persistente. Melhorar a UX e testar associação temporal sem trocar de aluno.
2. Separar métricas `sem pose`, `sem alvo selecionado`, `alvo incerto` e `pose sem ângulo confiável`.
3. Testar originais MOV 4K, HEVC/10-bit, rotação, memória e duração total **no aparelho físico** quando disponível; o simulador usou transcodificações curtas.
4. Comparar estado do rastreador e contagem às anotações independentes antes de alterar limiares ou treinar o classificador. Professores, visitantes e pôsteres precisam de rótulos negativos explícitos; um filtro por posição vertical seria específico da cena.

## Verificações automatizadas após a alteração

Em 25/09, `swift test` aprovou **39/39** testes do núcleo. `xcodebuild test` no simulador iPhone 15 aprovou **44/44** (39 núcleo + 5 UI), conforme `Test-SquatCounter-2026.09.25_09-34-57--0300.xcresult`. O runner informou falha ao **coletar diagnósticos adicionais** porque uma chamada interna não encontrou `simctl`, mas `xcresulttool` confirmou resultado `Passed`, 44 aprovados, 0 falhas, 0 pulados. A verificação de rotação e os oito clipes acima são ensaios de integração DEBUG, não testes UI automatizados nem medição física.
