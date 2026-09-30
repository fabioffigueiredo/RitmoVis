# Teste real no box — investigação de 30/09/2026

Estado: falha de acompanhamento observada; causa específica por quadro ainda não adjudicada. Este registro inclui pesquisa e proposta de produto, **não aprovação de arquitetura nem implementação de gesto**.

## Evidência

O **iPhone de fabio físico** estava conectado; os simuladores estavam desligados no início da investigação. Xcode mostrava a tela de boas-vindas; duas tentativas de controle do Device Hub excederam o tempo de resposta. Não foi possível confirmar qual replay estava aberto. O contêiner foi lido por `devicectl`, sem reiniciar/reinstalar o app ou cancelar reprodução.

Índice, duas gravações longas e sidecars foram copiados, sem remover originais, para `~/Library/Application Support/RitmoVis/qa-private/box-20260930/`. Nenhuma mídia pessoal entra no Git. O Histórico registra seis gravações novas na manhã de 30/09, todas com zero eventos. Casos inspecionados:

| Gravação | Duração do arquivo | Amostras de replay | Pedindo reseleção | Identidade incerta | Contagem máxima |
|---|---:|---:|---:|---:|---:|
| Traseira, longa | 176,92 s | 3.301 | 2.156 | 102 | 0 |
| Frontal, mais longa | 231,30 s | 4.296 | 3.643 | 102 | 0 |

São estados processados, não todos os quadros de câmera nem falhas independentes. `reselectionRequired` é absorvente até nova escolha; milhares de amostras podem resultar de uma única perda. O índice registra 3.302/4.297 quadros processados; a diferença de uma amostra não comprova corrupção. `noPoseFrames` mistura ausência de seleção e de ângulo útil, não mede falha bruta de detecção.

A inspeção amostrada mostra vários participantes, aproximação com corpo cortado e movimento do telefone/enquadramento. Ainda faltam rótulos completos de atleta, ciclos e observabilidade. Zero eventos não permite medir recall; landmarks não são verdade humana. Priorizar a **primeira perda**, o intervalo anterior e os primeiros ciclos humanos.

## Mecanismos encontrados no código

- `WorkoutSession.prepareWorker` limita Vision/hybrid/modo independente à importação. Ao vivo usa MediaPipe Lite/Full, modo vídeo e até quatro poses. Os testes de Vision/recorte não comprovam melhora da câmera.
- O candidato precisa de oito pontos visíveis; contar exige quadril/joelho/tornozelo confiáveis. Selecionável não é contável. Aproximação pode cortar o corpo.
- Toque ao vivo pode ser recusado por observação antiga, deslocamento/tamanho ou ambiguidade, sem devolutiva estruturada; a UI anuncia confirmação antes da resposta.
- A espera de três segundos bloqueia contagens, não o rastreador. Este pode invalidar a seleção durante a volta à posição (0,8 s sem aparência / 2 s com aparência, ou ambiguidade). Não “corrigir” congelando identidade sem evidência.
- Associação usa geometria da imagem e resumo temporário da roupa, sem compensar movimento da câmera. O replay não conserva todos os candidatos/confianças/rejeições necessários para explicar cada perda.
- Histórico reproduz vídeo e análise salva; não roda nova inferência automaticamente.

## Direção de produto proposta

Primeiro: um atleta, celular fixo/apoiado, agachamento escolhido explicitamente. Armar no telefone uma janela de início sem toque; já em posição, executar gesto deliberado sustentado e abaixá-lo; seleção só se toda a sequência pertencer ao **mesmo track**, com confirmação audível e corpo/articulações observáveis. Um braço por ~1,5 s e abaixar por ~0,5 s é hipótese, não tempo validado. Cancelar em ambiguidade ou múltiplos executantes; testar professor demonstrando e exercícios como negativos. Um único gesto não comprova intenção sozinho.

**Recuperação não é troca de alvo.** Após perda durante a série, gesto de qualquer pessoa não pode assumir a sessão. Recuperar requer evidência compatível com o alvo anterior; mudar atleta exige ação explícita. Preservar total e invalidar repetição parcial quando a identidade for incerta.

Separar detecção de pessoa, associação temporária, pose e contador. Avaliar pose no recorte do atleta com margem suficiente e redetecção ampla; manter imagem original. Roupa/geometria/embedding são evidências auxiliares e locais à sessão, não identidade garantida. Atualizar aparência apenas sob associação inequívoca. Zoom digital não cria detalhe nem resolve oclusão; não trocar lente automaticamente na primeira versão.

Comparar três caminhos: baseline melhorado (menor custo de engenharia); detector independente + pose no ROI (recomendado como experimento); múltiplas câmeras/turma (produto posterior). Primeiro comprovar o segundo contra o primeiro, com contador e rótulos iguais. Câmera móvel fica fora da primeira promessa; registrar sua falha sem descartá-la do corpus.

## Pesquisa de modelos

| Componente | Candidatos | Antes de adotar |
|---|---|---|
| Baseline | MediaPipe Lite/Full; Vision no iOS | mesmo corpus/pipeline e comparação física |
| Pose em ROI | RTMPose-t/s + detector; MoveNet | contrato de pontos, pesos/licença, exportação e benchmark Core ML/LiteRT |
| Detector/pose móvel | YOLO26 nano/pose | exportações oficiais; revisar AGPL/Enterprise para produto proprietário; números de outro iPhone não são nossos |
| Aparência | OSNet x0.25 | candidato mais antigo, não “modelo mais recente”; verificar checkpoint/licença, conversão, roupas semelhantes e custo |
| Associação | geometria/movimento + aparência; compensação como BoT-SORT | associação não é detecção nem portabilidade móvel automática |

YOLO27 aparece em fontes oficiais, mas páginas consultadas divergem entre anúncio/documentação e disponibilidade; não prometer pesos utilizáveis. Nenhum modelo novo foi instalado, comprado ou substituído. Antes de fine-tuning, distinguir alvo ausente, ID trocado, ângulo indisponível, preparação ativa e ciclo interrompido. Separar sessões de ajuste/aceitação; mais vídeos sem rótulos não são treinamento.

Fontes primárias: [RTMPose](https://arxiv.org/abs/2303.07399), [deploy MMPose](https://github.com/open-mmlab/mmpose/blob/main/docs/en/user_guides/how_to_deploy.md), [YOLO Core ML](https://docs.ultralytics.com/integrations/coreml), [licenciamento Ultralytics](https://www.ultralytics.com/license), [OSNet](https://huggingface.co/kaiyangzhou/osnet), [BoT-SORT](https://github.com/NirAharon/BoT-SORT), [LiteRT](https://developers.google.com/edge/litert/overview).

## Câmera no desenvolvimento

Apple documenta que **iPhone Mirroring não oferece câmera/microfone**. Pareamento de desenvolvimento, espelhamento interativo e Continuidade são distintos. OBS usa o iPhone como câmera do Mac pela última rota. Os vídeos novos têm imagem real, mas não registram estado de pareamento/espelhamento durante gravação; a causa histórica de quadros pretos continua aberta.

Simulator não oferece câmera nativa conforme AVCam. Webcam do Mac pode alimentar um harness macOS ou uma ponte local explicitamente DEBUG; seria um caminho adicional, não configuração nativa nem QA físico. Ferramentas externas de injeção não foram instaladas/auditadas. Importação permanece a reserva reproduzível.

Próximo A/B combinado: fechar espelhamento e consumidores de Continuidade; aparelho desbloqueado com app em primeiro plano e pareamento mantido; comparar câmera nativa/app, imagem física, luminância e notificações. Não cancelar pareamento ou mudar privacidade por tentativa aleatória. Referências/vídeos: [iPhone Mirroring](https://support.apple.com/en-us/120421), [AVCam/Simulator](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app), [Continuity Camera — WWDC22](https://developer.apple.com/videos/play/wwdc2022/10018/), [corpo/mãos/gestos — WWDC20](https://developer.apple.com/videos/play/wwdc2020/10653/).

## Crítica final e próximo experimento

GPT‑6 Astra revisou estratégia/código, sem editar ou tocar no telefone. Incorporadas: recuperação separada de troca, gesto no mesmo track, primeira perda em vez de somar estados absorventes, aparência não contaminada e avaliação que não esconde perdas por abstenção. Flexão continua oculta: a geometria sintética não confirma posição horizontal/exercício ou continuidade do lado.

Rotular os dois clipes existentes → reconstruir primeira perda com baseline congelado → comparar **um** desafiante detector + ROI. Separadamente testar gesto com professor, polichinelos, cruzamento, roupas iguais, corpo cortado e perda durante série. Medir ativações falsas/hora, seleção correta, conclusão/latência do início e cobertura de identidade/articulações. Recall inclui ciclos completos dentro do escopo perdidos pelo sistema; reportar inobservabilidade humana separadamente. Cinquenta ciclos são coleta inicial, não prova suficiente de beta. Não avançar para exercícios novos, técnica ou turma antes da beta individual iOS e Android físico.
