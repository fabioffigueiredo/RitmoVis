# Evolução testada do RitmoVis

**Estado em 25/09/2026:** existe um contador experimental de agachamento no iPhone 15, com importação de vídeo, câmera frontal/traseira, gravação opcional, histórico e replay. M2 possui seleção em cache, abstenção e experimento Vision/calibração, mas **não passou** no gate físico: no clipe de grupo, houve três eventos e perda do alvo após 12,52 s, sem anotação independente completa. Quatro vídeos pessoais agora formam um [corpus privado de casos difíceis](docs/qa-private-videos-2026-09-25.md); oito trechos passaram pelo detector no simulador, mas o rastreamento após seleção teve cobertura insuficiente. Nenhum modelo foi retreinado. O clipe de uma pessoa teve quatro eventos observados; nada disso valida precisão geral, técnica ou operação em turma. O produto futuro terá iOS **e Android**, com betas separadas e os mesmos critérios de aceitação. Use [handoff](docs/claude-handoff.md), [QA M2](docs/qa-group-selection-2026-09-24.md) e o novo relatório como estado atual; cada marco só avança com evidência registrada em `docs/qa-status.md`.

**Incremento de 25/09:** o rastreador de alvo ganhou evidência cromática temporária, recuperação conservadora e diagnósticos por categoria; a seleção offline não reaproveita o quadro anterior ao pedir novo alvo. O [reensaio](docs/qa-single-target-2026-09-25.md) melhorou a continuidade de alguns trechos e deixou outros praticamente iguais, mas **não comprova identidade nem contagem correta**. O próximo gate é coletar/rotular o [roteiro de 20 clipes](docs/recording-protocol-single-target.md), separar ajuste e holdout por sessão e medir contagens atribuídas à pessoa errada e cobertura; 50 ciclos são piso de coleta, não prova de generalização. Um novo vídeo do Histórico de 25/09 foi preservado como possível caso de regressão, sem rótulo humano.

## M0 — consolidar o agachamento de uma pessoa

**Progresso:** avaliador de eventos, fixture sintético, quatro testes e protocolo de anotação implementados em 23/09/2026. Coleta real, ensaio sustentado e gate de aceitação ainda pendentes.

**Implementar:** estabilizar a câmera no aparelho físico, confirmar rotação/replay e tratar recursos ausentes. Separar métricas de tempo até primeiro quadro, inferência, FPS processado, perdas, latência p95, temperatura e bateria por câmera e modelo Lite/Full.

**Dados e teste:** anotar manualmente pelo menos 50 ciclos em gravações autorizadas de pessoas/ângulos/iluminação variados, com início/fim de cada repetição e tentativas incompletas. Executar 10 minutos contínuos de câmera ao vivo. Testar frente/trás, retrato/paisagem, entrada/saída do quadro, oclusão, pausa, interrupção e gravação ligada/desligada. Reportar TP/FP/FN, duplicações e instante do +1, não só o total.

**Gate:** em cenário controlado definido antes do ensaio, alvo de precisão e recall ≥95% nas repetições avaliáveis, ≥15 quadros processados/s sustentados e nenhum arquivo corrompido. Falhar ou não coletar todos os dados significa “experimento com limites”, não funcionalidade validada. Ensaios independentes ainda serão necessários para alegação de generalização.

## M1 — exercícios adicionais, um por vez

**Arquitetura:** introduzir protocolo de detector de exercício com estado por movimento, regra explícita de início/fim, tratamento de repetição parcial e classe `desconhecido`. O usuário confirma o exercício; reconhecimento automático só entra depois de dados rotulados e matriz de confusão. Começar por flexão de braços em vista lateral controlada e, em seguida, avaliar burpee com padrão definido com treinador; não reutilizar ângulos/limiares do agachamento por analogia.

**Comparação:** medir Lite, Full e qualquer modelo novo no iPhone 15 com o mesmo corpus, pré-processamento e orçamento térmico. Registrar pesos, licença, versão, latência p50/p95, FPS, memória, energia, FP/FN e casos em que o modelo deve abster-se. Só trocar o modelo padrão quando houver ganho observado sem regressão importante de desempenho ou privacidade.

**Gate:** testes unitários da máquina de estados, fixtures anotadas e ensaio físico do novo movimento; publicação de resultado por exercício e condição, não uma precisão única do app.

## M2 — selecionar e manter **uma** pessoa numa cena com várias

**Implementar:** múltiplas poses, seleção manual por toque/área de treino, IDs temporários apenas na sessão e associação temporal por posição/pose. Lista de poses do MediaPipe não é identidade estável. Congelar contagem e pedir nova seleção quando cruzamento, oclusão ou saída/reentrada tornarem a associação ambígua. Sem reconhecimento facial.

**Importação experimental:** Arquivos/Fotos e replay estão implementados; em grupos, o app descarta contagens provisórias até o usuário tocar no aluno e reavalia poses em cache a partir do quadro escolhido. MediaPipe teve associação instável no clipe físico; Vision com calibração acompanhou 313/430 quadros e contou três eventos antes de perder o alvo. O próximo incremento precisa medir e melhorar cobertura **sem elevar trocas de identidade**, usando vídeos reais anotados e uma experiência clara para reseleção. Caixas de detecção não identificam professor/aluno por si.

**Teste:** vídeos consentidos com cruzamentos, oclusões, câmera frontal espelhada e duas pessoas fazendo repetições ao mesmo tempo. Anotar atleta-alvo por quadro/evento; medir trocas de identidade, contagens atribuídas à pessoa errada, tempo de recuperação e abstenções. Meta inicial: **zero contagens cruzadas nos fixtures anotados**; este gate não significa robustez em qualquer academia.

## M3 — sinais observáveis de execução

**Implementar:** somente avisos revisáveis como amplitude abaixo de um limiar definido para o exercício e enquadramento insuficiente. Profissional de educação física define exemplos positivos/negativos por ângulo; limiares e mensagens são versionados. Quando a pose não sustentar avaliação, apresentar “não foi possível avaliar”. Nunca declarar segurança, risco de lesão ou correção global a partir de uma câmera monocular.

**Teste:** corpus consentido anotado independentemente por especialistas, com desacordos preservados. Medir sensibilidade/especificidade e falsos alertas por câmera/ângulo/oclusão; revisão humana antes de alerta a professor. Gate de produto só após concordância e limites aceitáveis definidos com o profissional.

## M4 — aula piloto no box ou academia

**Primeiro piloto:** 2–4 alunos voluntários, identificados por check-in/posição de estação, com estado, cronômetro e contagem independentes por aluno. O professor recebe relatório revisável; vídeos brutos ficam locais ou seguem retenção curta explicitamente acordada. Não usar identificação facial nem inferir quem é aluno sem cadastro/consentimento.

**Dimensionamento:** levantar campo de visão, oclusões e sobreposição por estação; comparar câmera por estação, poucas câmeras compartilhadas e processamento local/servidor. Instrumentar decodificação, inferência multi-pose, associação, filas, memória, temperatura, rede e quadros perdidos no hardware real. Jetson Orin NX 16 GB e NVIDIA L4 24 GB são candidatos a benchmark, não capacidade prometida. Escalar para turma inteira só depois do piloto e de testes com carga e cruzamentos representativos.

**Gate:** comparar relatório por aluno com anotação manual, incluindo FP/FN, troca de identidade, duração e períodos de abstenção; nenhum resultado de um aluno deve ser creditado a outro nos cenários de aceitação. Antes do piloto, definir responsável pelo tratamento, base legal, transparência, acesso, retenção e avaliar RIPD com assessoria adequada. [ANPD](https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/relatorio-de-impacto-a-protecao-de-dados-pessoais-ripd)

## Betas individuais iOS e Android — antes de M4

**Beta iOS para profissionais:** somente após M0 e M2 passarem em conjunto de aceitação independente: nenhuma repetição creditada a outra pessoa, precisão e recall ≥95% nas repetições avaliáveis, cobertura ≥80% das repetições observáveis, captura sustentada e arquivos íntegros. Completar permissões, interrupções, gravação, replay, exclusão, pouco espaço, acessibilidade e TestFlight. O resultado fica limitado ao corpus/aparelhos ensaiados.

**Android A0:** criar `android/` nativo em Kotlin após o gate da beta iOS, começando por importação de vídeo e mesma máquina de estados, limiares e eventos dos fixtures versionados em `fixtures/`. Nada de portar o código Swift para um framework multiplataforma antes de medir custo e divergência. **A1:** CameraX com prévia/análise, MediaPipe Pose Landmarker, seleção temporária, gravação/replay e histórico. Usar estratégia não bloqueante para o analisador e sempre liberar `ImageProxy` após análise, conforme [CameraX](https://developer.android.com/media/camera/camerax/analyze). **A2:** repetir o gate em pelo menos um Android intermediário e um recente, físicos, mais emulador para compatibilidade; restringir aparelhos suportados se necessário. O [MediaPipe Android](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/android) suporta câmera e vídeo, mas uma compilação não valida FPS, energia ou contagem. Piso provisório Android 8/API 26. Sem Android Studio/SDK/Gradle/ADB utilizáveis nem aparelhos Android informados neste Mac em 24/09; instalação, escolha de aparelhos e testes são passos futuros, não concluídos.

O fixture `fixtures/tracking-v1-synthetic.json` é contrato comportamental **sintético**, não vídeo de aceitação: traz tempo, candidatos por quadro, seleção após quadro, decisão esperada e contagem. Índices são locais ao quadro; não são identidade nominal. O teste Swift lê este arquivo hoje; o futuro núcleo Kotlin deverá ler o **mesmo** arquivo sem reinterpretar os estados. Diferenças de pose entre modelos/aparelhos serão medidas separadamente. Por padrão, inferência permanece no aparelho e dados pessoais fora do Git.

## M5 — ocupação da academia (produto separado)

Detectar/rastrear pessoas por zona de câmera e enviar somente contagens agregadas para capacidade definida pela unidade. O mapa de calor representa **presença acumulada**, não temperatura. Horário de pico requer semanas de histórico real; um vídeo público só demonstra o pipeline. Dimensionar câmeras por campo de visão e zonas, validar dupla contagem e testar carga antes de prometer disponibilidade em rede de academias. Não misturar esse dado com identidade ou avaliação técnica de alunos sem novo desenho de privacidade.

## Regras permanentes

- Arquivos usados em teste/publicação precisam de autorização e proveniência; dados pessoais não entram no Git.
- Cada hipótese de desempenho exige protocolo, corpus, versão do modelo, dispositivo e resultados reproduzíveis. Número de repetições anotadas e duração são volume de coleta, não prova de generalização.
- Mudar modelo ou hardware só após comparar qualidade, latência, energia, custo e licença comercial no caso real.
- Nome RitmoVis e identidade visual são provisórios; verificar marca e bundle identifier antes de distribuição pública.
