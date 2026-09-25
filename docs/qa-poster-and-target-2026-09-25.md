# M2 — pôster e perda do alvo (25/09/2026)

## Origem e escopo

Vídeo de tela enviado pelo proprietário: `ScreenRecording_09-25-2026 15-59-34_1.MP4`. Contém o app analisando vídeos pessoais no Histórico. Cópias e relatórios detalhados ficam somente em `~/Library/Application Support/RitmoVis/qa-private/screen-20260925/`, fora do Git. O proprietário prefere filtragem totalmente automática, sem marcar área do piso.

No clipe com duas atletas há um pôster de uma pessoa na parede. O Apple Vision, que estima poses em imagens, o devolveu como candidato em 457 quadros. Antes da correção, uma escolha deliberada do pôster acompanhava 619 quadros, mas apenas 57 tinham ângulo de joelho utilizável; nos primeiros 2 s, 1 de 49. A seleção da atleta real à direita tinha ângulo utilizável em 60/60 quadros nos mesmos primeiros 2 s. Isto reproduz a falha de **seleção**, não uma alegação de que o app contou uma repetição do pôster.

No clipe de turma, o homem de camiseta preta selecionado aos 2 s encolhe a caixa de corpo inteiro durante a flexão; o centro do tronco permanece mais estável. O rastreador anterior rejeitava variação de tamanho da caixa e acompanhou 21 quadros, ficou incerto em 72 e exigiu reseleção em 713. A pessoa escolhida caminha ao longo da sala no fim do clipe; deslocamento horizontal grande ao longo de 20 s não é, sozinho, troca de identidade.

## Alteração implementada

`PoseDetector` agora fornece centro e comprimento de ombros–quadris ao `TargetTracker`. Havendo quatro articulações confiáveis, a associação usa esta geometria; se não houver, preserva o caminho conservador da caixa. O tracker continua se abstendo em ambiguidade; isto não é reconhecimento pessoal.

Em vídeo importado com várias poses, `VideoSelectionEligibility` exige pelo menos 12 quadros acompanhados, 10 ângulos de joelho utilizáveis e pelo menos 50% de quadros acompanhados com ângulo na janela de até 2 s a partir da escolha. Candidatos que falham não aparecem como alvos selecionáveis e uma chamada direta de seleção também é recusada. Isto filtra o **pôster parcial observado**; não prova detecção geral de foto ou prova de vida. Uma fotografia de corpo inteiro com articulações estimadas de forma consistente ainda pode passar. O filtro se aplica à seleção de vídeo importado de grupo, não à câmera ao vivo nem a todos os exercícios futuros.

## Verificação

| Ensaio no iPhone 15 físico | Antes | Depois | Interpretação |
|---|---:|---:|---|
| Turma, homem de preto, Apple Vision | 21/866 quadros selecionados; 72 incertos; 713 reseleção | 428/866 selecionados; 309 incertos; 69 reseleção | Continuidade melhor, mas cobertura e identidade ainda não validadas; 0 eventos neste ensaio, pois o alvo não executa agachamento completo. |
| Duas atletas, alvo à direita | 692/693 selecionados; 2 eventos | 692/693 selecionados; 2 eventos | Sem regressão observada neste clipe. |
| Duas atletas, escolha do pôster | 619 selecionados após escolha | escolha recusada; relatório permanece no primeiro passe (`selectionRequested=false`, 0 quadros selecionados) | O pôster deste clipe não entrou na análise como aluno. |

`swift test`: 54/54 testes do núcleo. `xcodebuild test` no simulador iPhone 15: 59/59 (54 núcleo + 5 UI), resultado `TEST SUCCEEDED` em `/tmp/ritmovis-m2-posterfix-sim.log`. O runner voltou a avisar que não encontrou `simctl` ao coletar diagnósticos extras; não houve falha de teste. O build Debug foi instalado no `iPhone de fabio`; testes de vídeo usaram arquivos de QA privados já copiados ao contêiner do app. Nenhuma gravação do Histórico foi removida.

## Limites e próximo gate

Os números são rastros automáticos dos próprios detectores, **não** rótulos humanos de ID correto, falsos positivos ou precisão de contagem. Revisar manualmente quadro a quadro os trechos de cruzamento e todos os eventos, separar sessões de ajuste/aceitação, e medir troca de identidade, cobertura útil, contagens atribuídas a outro aluno e falsos candidatos estáticos. Incluir fotos/pôsteres de corpo inteiro, espelhos, TV, oclusão e baixa iluminação. Só então ajustar limiares ou avaliar detector temporal/segmentação adicional. M2 e beta continuam pendentes.
