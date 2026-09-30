# Gestos e instruções — experimento de 30/09/2026

## Escopo aprovado e implementado

Na preparação, **Comandos por gesto · experimental** está desligado por padrão. Só afeta o pipeline da câmera, nunca importação/replay normal. A [fonte gravada DEBUG](qa-recorded-camera-2026-09-30.md) pode exercitar esse pipeline sem lentes, com aviso explícito. Com celular fixo e corpo inteiro observável: levantar a mão acima do ombro, palma aberta voltada para a câmera e sustentar por 2 s seleciona um único atleta e arma a espera existente de 3 s antes de contar. Punho fechado, também levantado e sustentado por 2 s, encerra a sessão somente quando associado ao atleta atualmente acompanhado. O início/parada por gesto têm confirmação falada local; botões Selecionar/Parar continuam disponíveis.

As instruções mudam conforme preparação, ausência de corpo, seleção e perda de foco. O progresso mostra o tempo de sustentação reconhecido. A janela de seleção inicial termina em 30 s; o usuário pode selecionar manualmente ou parar e reiniciar. Depois de selecionar alguém, uma nova palma não recupera nem transfere identidade: em perda/incerteza é necessário confirmar manualmente. Essa limitação é explícita para evitar que um colega herde o treino.

Isto resolve uma hipótese de **alcance do controle**, não a falha real de rastreamento descrita em [investigação do box](box-investigation-2026-09-30.md). Não houve retreinamento de pesos, novo detector de pessoas, reconhecimento de exercício ou avaliação de técnica.

## Pipeline e proteções

- MediaPipe Gesture Recognizer oficial, versão 1/float16, executado localmente em modo vídeo na fila de inferência existente, no máximo a cada 100 ms; modelo de pose continua Lite/Full conforme escolha.
- Mão → punho corporal visível e ombro da mesma pose; verificar ambiguidade em **todas as poses**, inclusive rivais sem candidato selecionável ou ombro válido. Só depois exigir corpo/articulações utilizáveis para comandar. Um retângulo contendo a mão, sozinho, não é identidade.
- Classificação ≥0,8 e mão acima do ombro. Sustentação contínua de 2 s, timestamps estritamente crescentes e intervalos ≤250 ms; falha reinicia a sustentação. Dois comandantes ou gestos conflitantes cancelam o comando.
- `HandGestureControl` rastreia o mesmo candidato durante a sustentação, incluindo rivais desde o primeiro quadro; índices de arrays nunca são IDs. Eventos de selecionar/parar são emitidos uma vez por sessão. Perda do foco suspende comandos.
- Inferência de mão entra na latência do quadro. Quadro descartado segue o mecanismo de fila existente. Não afirmar que os 10 Hz de amostragem garantem 10 Hz no aparelho: medir custo e lacunas reais.
- Erro de inferência mostra alternativa manual. Modelo ausente recusa início com mensagem; desligar a opção preserva o caminho anterior.

Mão detectada em imagem não comprova pessoa viva. Pôster, tela com mão, colega único realizando gesto e falsos comandos durante exercício exigem negativos reais; a implementação não é autenticação nem prova de intenção.

## Evidência automatizada

Núcleo completo: **117/117** em 30/09 às 19:39, sendo 29 de comandos por gesto e 8 de associação; ferramentas Node **21/21**. A execução completa final com as três regressões de encerramento passou **134/134**, zero falhas/skips, em `Test-SquatCounter-2026.09.30_19-49-00--0300.xcresult` (117 núcleo + 10 UI + 7 hospedados). Os dois avisos internos de inversão de QoS permanecem como investigação, sem atribuir impacto à câmera real; avisos de APIs AVFoundation descontinuadas e coleta de diagnóstico do simulador não foram ocultados.

TDD e revisão Astra: sobreposição com rival cortado/ombro inválido e perda de alvo entre leituras de mãos receberam regressões RED→GREEN. O adaptador inicialmente descartava um rival com punho confiável mas menos de oito landmarks úteis, pois iterava só candidatos selecionáveis: a fixture real mais duas poses sintéticas reproduziu a falha (`An unselectable rival wrist must still block ownership`), e iterar todas as poses fez o teste passar. Esta associação artificial testa o adaptador, não inferência de dois corpos reais. O fim da fonte gravada descartava resultado ainda em processamento/publicação: testes com resultado terminal e inferência atrasados falharam antes das correções e passaram depois; um teste adicional cobre fonte vazia.

`SquatCounterInferenceTests` é hospedado no app: usa a fixture oficial `fist.jpg` em BGRA e o reconhecedor real em modo vídeo, não mock de inferência. Uma mão sem pose corporal não pode virar candidato. A fixture fica fora do Git; se ausente, o teste é **skipped**, não aprovado. Seu resultado não mede reconhecimento de corpo inteiro à distância, iluminação do box ou contagem.

O primeiro teste hospedado abortou por duplo carregamento do registro estático de calculadores MediaPipe. O app já carrega esse registro; o target de testes hospedados remove apenas seu próprio `OTHER_LDFLAGS` herdado para não repetir o `force_load`. XcodeGen é a fonte da configuração. O aviso CocoaPods sobre esse override é intencional; não restaurar `$(inherited)` sem reproduzir o teste. MediaPipe continua na versão instalada 1.0.0, sem troca de modelos de pose.

## Recursos e reprodução

Modelo oficial: [bundle versão 1](https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task), SHA-256 observado `97952348cf6a6a4915c2ea1496b4b37ebabc50cbbf80571435643c455f2b0482`; download verificável em `ios/Scripts/download_models.sh`. Sem binário no Git. [Cartão do classificador](https://storage.googleapis.com/mediapipe-assets/gesture_recognizer/model_card_hand_gesture_classification_with_faireness_2022.pdf) descreve gestos estáticos, não aceno em movimento, e não valida todas as condições reais de celular. Repositório e testdata MediaPipe declaram Apache 2.0; cartão isolado não atesta licença de todos os componentes do bundle.

Fixture [fist.jpg oficial](https://storage.googleapis.com/mediapipe-assets/fist.jpg), SHA-256 `43fa1cabf3f90d574accc9a56986e2ee48638ce59fc65af1846487f73bb2ef24`. Obter para `ios/Sources/SquatCounter/Resources/gesture-fixtures/fist.jpg` apenas no ambiente privado; regenerar projeto com XcodeGen e CocoaPods. Os [testes oficiais](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/tasks/javatests/com/google/mediapipe/tasks/vision/gesturerecognizer/GestureRecognizerTest.java) rotulam essa fixture como punho fechado. `right_hands.jpg` não foi rotulado como palma aberta nesta avaliação.

Vídeos candidatos: [aceno em corpo inteiro, Pexels 5510480](https://www.pexels.com/video/boy-waving-his-hands-5510480/) e [cumprimento com punhos, Pexels 5362602](https://www.pexels.com/video/two-men-greets-each-other-with-fist-bump-5362602/). Apenas metadados pesquisados; não baixados/anotados nem considerados exemplos positivos de sustentação válida. [Licença Pexels](https://www.pexels.com/license/) permite edição, não endosso/redistribuição como stock. Preferir gravações próprias consentidas para o gesto exato e a distância de treino. Vídeo gerado por IA serve apenas como adversarial/UI, nunca acurácia real.

## Instalação e próximo ensaio físico — ainda pendente

Build/instalação desta versão no **iPhone de fabio** concluídos, com índice do Histórico preservado. Abertura para teste com clipe recusada pelo iOS porque o aparelho estava bloqueado; runner de UI físico também sem perfil de assinatura. [Evidência e continuação](qa-recorded-camera-2026-09-30.md). Não houve reconhecimento positivo de gesto no telefone nesta execução.

No **iPhone de fabio**, após terminar replay e aceitar atualização, confirmar câmera real visível sem espelhamento que a bloqueie. Celular fixo, frontal e traseira, retrato/paisagem. Gravar privadamente:

1. Corpo inteiro: palma levantada 1 s (não iniciar), depois 2–3 s (selecionar uma vez); abaixar e realizar cinco agachamentos com referência humana. Punho 1 s (não parar), depois 2–3 s (parar uma vez).
2. Repetir em 2, 3 e 4 m, luz clara/box, roupa clara/escura; registrar tamanho da mão, sucesso/tempo de comando e motivo de recusa. Distâncias são coleta, não faixa suportada.
3. Outra pessoa faz palma/punho enquanto atleta segue selecionado; cruzamento e oclusão. Nenhum comando deve transferir o treino, e total deve permanecer preservado na perda.
4. Palma e punho de pessoas diferentes, duas mãos conflitantes, professor acenando, polichinelo, mão segurando peso, pôster/tela com pessoa. Registrar falsos comandos, inclusive antes da seleção.
5. Corpo cortado, braço baixo, mão longe/pouco legível, janela expirada, rotação/interrupção, câmera preta. Instrução deve ser acionável, e botão Parar sempre acessível.
6. Ensaio sustentado de 10 min com opção ligada/desligada: FPS, p95 de inferência/atraso de comando, perdas, temperatura/bateria e integridade da gravação. Comparar no mesmo aparelho, sem extrapolar para Android.

Gate deste incremento: nenhuma transferência indevida ou falsa parada nos negativos rotulados e sucesso/latência documentados nos positivos reais. Beta geral continua bloqueada pelos gates M0/M2 de identidade e contagem, independentemente dos gestos.
