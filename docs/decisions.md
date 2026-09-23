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

Reavaliar cada decisão com testes e registrar data, evidência, trade-off e migração antes de substituí-la. Não confundir uma hipótese de roadmap com recurso implementado.
