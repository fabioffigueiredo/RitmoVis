# Decisões arquiteturais e de produto

| ID | Decisão vigente | Motivo e limite |
| --- | --- | --- |
| D-01 | Contagem experimental no aparelho, com MediaPipe Lite/Full e regras explícitas | Mantém vídeo local por padrão; 4/4 em um clipe não valida precisão geral. |
| D-02 | Usuário escolhe o exercício; reconhecimento automático fica para depois | Classificar exercício exige dados rotulados, classe `desconhecido` e confirmação. |
| D-03 | Gravação é opcional; histórico/replay persistem localmente | Requer tratamento de permissão, espaço insuficiente, exclusão e arquivos incompletos. |
| D-04 | Seleção manual e ID temporário em M2, sem reconhecimento facial | Multi-pose não fornece identidade persistente. Contagem deve abster-se quando associação for ambígua. |
| D-05 | Feedback de forma apenas como sinais observáveis e revisáveis em M3 | Uma câmera monocular não demonstra correção ou segurança; exige rótulos de especialista. |
| D-06 | Produto de ocupação agregado fica separado do relatório individual de treino | Finalidades, privacidade, retenção e métricas de erro diferem. |
| D-07 | Código e documentação no Git; mídia, modelos, dados pessoais e segredos fora | Preserva privacidade, tamanho do repositório e revisão de licenças. Modelos oficiais são baixados com checksum. |
| D-08 | RitmoVis é nome provisório; `SquatCounter` permanece em alvos técnicos por ora | Evita renomeação cosmética antes de concluir QA e verificar marca/bundle ID. |
| D-09 | Dois apps nativos, Swift/iOS primeiro e Kotlin/Android após gate da beta iOS | Um JSON de fixtures e métricas comuns reduz divergência sem migração prematura de framework. Android não bloqueia a primeira beta iOS, mas deve passar os mesmos critérios. |
| D-10 | Ambiguidade entre duas poses exige nova seleção; sumiço curto sem concorrente pode recuperar | Geometria isolada não prova identidade. Após cruzamento, recuperar automaticamente arrisca creditar a pessoa errada. Períodos de abstenção contam contra a cobertura útil no gate. |
| D-11 | Build de desenvolvimento usa `com.fabiofigueiredo.ritmovis.dev` e equipe já associada ao projeto anterior | Instala ao lado do protótipo antigo, preservando seu histórico. Identificador de lançamento público e TestFlight serão decididos após verificar marca e contas. |
| D-12 | Importação por Arquivos/Fotos analisa localmente e descarta contagens provisórias se detectar múltiplas pessoas | Uma pose isolada entre outras pode gerar contagem indevida. O clipe de grupo Pexels 6740245 revelou 3 eventos sem seleção antes da correção e zero depois. Agora o usuário pode escolher um alvo no replay para reanálise; a política é conservadora e a cobertura/identidade ainda exigem validação em M2. |
| D-13 | Seleção offline usa poses já analisadas e preserva o AVPlayer; Vision/calibração de referência em pé são opções explícitas e experimentais | Evita reinício visual e re-inferência ao tocar no alvo. Vision teve melhor cobertura no único clipe físico, mas não funcionou no simulador; calibração contou três eventos e não corrige identidade ou técnica. Não promover sem corpus anotado independente. |
| D-14 | Cor média do tronco é apenas evidência auxiliar, temporária e local à sessão; recuperação após lacuna exige dois quadros corroborantes | Melhora continuidade em alguns trechos privados, mas roupas iguais, sombra e iluminação podem confundir. Sem rosto, embedding persistente ou alegação de reidentificação validada. Se a cor falta ou conflita, abster-se/reselecionar; medir cobertura e troca de ID em holdout anotado antes de ampliar. |
| D-15 | Não retreinar pesos de pose ou identidade com os quatro vídeos pessoais | Amostra pequena, correlacionada e sem rótulos independentes. Primeiro executar `recording-protocol-single-target.md` com divisão por sessão e comparar baseline Lite/Full; pesos/termos de qualquer challenger exigem revisão específica. |

Reavaliar cada decisão com testes e registrar data, evidência, trade-off e migração antes de substituí-la. Não confundir uma hipótese de roadmap com recurso implementado.
