# Roteiro de gravação M2 — um aluno selecionado, agachamento

**Objetivo:** distinguir três falhas: corpo não detectado, detecção atribuída à pessoa errada e ciclo de agachamento não contado. Esta coleta não avalia técnica, segurança ou qualidade do movimento.

## Antes de gravar

1. Obtenha consentimento dos 3–4 adultos para **teste e possível ajuste local**. Consentimento para publicar vídeo ou compartilhá-lo com terceiros é separado. Não grave crianças ou frequentadores que não consentiram. Evite nomes, rostos recortados e localização precisa nas anotações.
2. Use iPhone 15 em tripé, preferencialmente câmera traseira 1080p/30 fps, corpo inteiro do alvo visível e distância fixa de aproximadamente 2–4 m. Mantenha uma tomada contínua de 60–90 s, sem câmera lenta, cortes ou filtros. Registre quando exposição, distância ou lente diferirem. Se o alvo ficar imperceptível para humanos, marque o trecho como *não observável*: o app deverá abster-se.
3. Antes de cada tomada, diga ou mostre apenas o **ID do clipe** e qual participante será selecionado (`A`, `B` etc.). O alvo fará pelo menos sete agachamentos completos, com pausas naturais, exceto nos clipes negativos. Os outros participantes podem ficar parados, caminhar, demonstrar e agachar conforme a matriz; anote suas repetições para flagrar crédito indevido.
4. Guarde originais e rótulos em armazenamento privado fora do Git. Preserve os originais; derive uma cópia 720p para o simulador. Registre SHA-256 do original e da cópia, aparelho, sistema, lente, orientação, luz/fundo, roupa, sessão/dia e âmbito do consentimento.

## Matriz: 20 clipes

| IDs | Quantidade | Cena / variável isolada | Resultado observável |
|---|---:|---|---|
| REF-01…03 | 3 | Alvo sozinho: frontal, lateral, luz uniforme. | Baseline da pose e da contagem. |
| CONTR-01…04 | 4 | Roupa preta/parede preta; repetir mesma posição/câmera com luz ou fundo contrastante; sombra lateral. | Separar falta de pixels úteis de falha de associação. |
| GRUPO-01…05 | 5 | Colegas imóveis, andando, agachando em ritmos iguais e diferentes; professor demonstra; roupas semelhantes. | Nenhum crédito a outra pessoa. |
| RETORNO-01…05 | 5 | Cruzamento; oclusão curta e longa; troca de lados; saída/reentrada; alvo muda de posição. | Pausa, preservação do total e retomada só com evidência forte. |
| NEG-01…03 | 3 | Alvo parado ou ausente enquanto outros agacham; objetos/pôsteres; movimentos incompletos. | Nenhuma repetição do alvo inventada. |

Distribua **12 clipes para ajuste** e **oito para aceitação**. Grave os oito em outra sessão ou dia; cada conjunto deve conter contraste baixo, grupo, cruzamento e negativos. A aceitação requer **50 ou mais agachamentos completos do alvo** somados; se oito clipes não alcançarem isso, grave clipes adicionais antes de calcular precisão/recall. Nunca dividir quadros de uma mesma sessão entre ajuste e aceitação. Com apenas 3–4 participantes, resultado favorável é evidência para piloto limitado, não generalização populacional.

## Anotação independente

Dois revisores marcam, sem olhar o resultado automático: pessoa-alvo selecionada, caixas/IDs temporários das pessoas, visibilidade a cada 0,5–1 s e em cruzamentos, início/fim de cada tentativa de agachamento (completa ou incompleta), repetições de não alvos e intervalos de oclusão/saída. Divergências são resolvidas antes da avaliação. Depois, um revisor associa cada caixa **prevista** ao ID humano ou a `incerto`, sem usar o índice da lista MediaPipe como identidade. O esquema em [m2-annotation-schema.md](m2-annotation-schema.md) é a referência; rótulos preenchidos ficam privados.

## Métricas e gates

- **Quadros observáveis:** alvo identificável por humano e articulações necessárias suficientemente visíveis para avaliar agachamento. Cobertura = quadros observáveis em que o app seleciona o alvo correto / todos os quadros observáveis. Uma abstenção segura reduz cobertura, mas não vira acerto de ID.
- **Troca de ID:** qualquer seleção de outra pessoa; reportar quadros, episódios e créditos de repetição atribuídos a ela. Selecionar alguém enquanto o alvo é não observável/ausente também é inseguro.
- **Contagem:** comparar eventos a repetições completas anotadas com `ritmovis-eval`; separar falsos positivos, falsos negativos e tentativas incompletas. Sem rótulos humanos, reportar somente diagnósticos, nunca acurácia.
- **Gate beta individual:** zero repetição creditada a outra pessoa; precisão e recall ≥95% em repetições avaliáveis; cobertura ≥80%; dez minutos de captura no iPhone físico sem corrupção, com FPS, latência, bateria e aquecimento registrados. Repetir em dois Androids físicos (um intermediário e um recente) antes de qualquer beta Android.

Os quatro vídeos recebidos em 25/09 são material de desenvolvimento/diagnóstico. Não usá-los simultaneamente para ajustar limiares e proclamar aprovação em holdout. Se a própria cena não permitir distinguir a pessoa, a UX deve explicar que a contagem está pausada e solicitar luz, contraste, enquadramento ou novo toque.
