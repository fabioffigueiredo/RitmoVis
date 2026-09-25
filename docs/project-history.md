# Histórico de engenharia — RitmoVis

Este é um registro de contexto, não uma lista de resultados de produto. Para o estado de QA vigente, veja [qa-status.md](qa-status.md) e [qa-group-selection-2026-09-24.md](qa-group-selection-2026-09-24.md).

| Data | Marco | Resultado e preservação de contexto |
|---|---|---|
| 23/09/2026 | Extração | protótipos `squat-counter-ios` e `squat-counter-video` foram copiados para o repositório independente. Originais não foram removidos. |
| 23/09 | Editorial | composições 16:9 e 4:5 foram preservadas como código Remotion; mídia e renders ficaram fora do Git. A publicação não foi automatizada. |
| 23/09 | M0 | avaliador de repetições anotadas e fixture sintético foram adicionados. O avaliador foi testado; corpus de pessoas reais continua pendente. |
| 24/09 | Dados privados | 12 vídeos autorizados do Histórico do app anterior foram copiados para área privada, sem apagar originais. Contagens antigas não são ground truth. |
| 24/09 | M2 inicial | `TargetTracker` adicionou seleção explícita, associação geométrica temporária, abstenção e descarte de ciclo parcial na incerteza. Índices MediaPipe continuaram sendo locais a cada quadro. |
| 24/09 | Falha de segurança corrigida | clipe Pexels de grupo produziu 3 eventos sem pessoa selecionada. `ImportedClipPolicy` passou a zerar contagem provisória se múltiplas pessoas aparecem em algum quadro. |
| 24/09 | Importação / replay | Arquivos e Fotos foram incluídos no app. O primeiro fluxo reiniciava o player ao selecionar alguém; comportamento relatado pelo proprietário como fechar/abrir vídeo. |
| 24/09 | Correção de replay | poses passaram a ser mantidas em cache e `OfflineTargetAnalyzer` reavalia tracker/contador sem decodificar ou recriar AVPlayer. Há guardas por token e player para evitar resultado antigo. |
| 24/09 | Experimento Vision | Apple Vision detectou três pessoas em cada quadro no iPhone físico do clipe de grupo; MediaPipe teve candidatos instáveis. Vision não produziu quadro analisável no simulador. |
| 24/09 | Calibração experimental | referência explícita de quadro em pé permitiu 3 eventos no clipe específico. O alvo foi perdido em 12,52 s. A fórmula e os limites estão no relatório de grupo; não virou padrão. |
| 24/09 | Revisão e QA | revisão estática Astra não encontrou bloqueador remanescente após correções de escopo/proveniência. 44/44 testes passaram no simulador; UI físico bloqueado por perfil de runner ausente/credencial Xcode inválida. |

## Incidentes que não devem ser esquecidos

1. **Prévia preta no pareamento:** no teste, Câmera nativa e RitmoVis apresentaram imagem preta com iPhone pareado/cabo; sem pareamento a imagem voltava. OBS/Continuity Camera demonstrou rota diferente (iPhone → Mac), não uma correção do AVFoundation do app. Causa não comprovada.
2. **Confundir detecção com identidade:** a primeira seleção em grupo acompanhou poucos quadros; Vision melhorou cobertura neste clipe mas não resolveu identidade persistente. Qualquer implementação futura deve contabilizar trocas de alvo e cobertura útil.
3. **Métricas de vídeo acelerado:** FPS durante importação offline não é FPS de câmera ao vivo. `noPoseFrames` em grupo pode significar apenas “alvo não selecionado”.
4. **Limiares específicos:** 155° padrão não alcançou o topo estimado no clipe de grupo. A calibração é uma hipótese por vista, não uma correção universal.

## Pontos de continuidade para outra sessão

- Começar em `docs/claude-handoff.md`, não em commits antigos.
- Atualizar este histórico quando houver uma evidência nova que mude decisões ou risco; não registrar cada pequena edição.
- Atualizar `qa-status.md` somente com execução datada e reprodutível; distinguir simulador, iPhone físico e observação humana.
- Ao avançar marco, atualizar roadmap, decisões, arquitetura, protocolo de dados e handoff na mesma mudança.
