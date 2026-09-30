# Fonte gravada na tela de captura — 30/09/2026

## Escopo

Pedido: enviar vídeos para o **iPhone de fabio** e simular uma câmera aberta para examinar a interface e o processamento no aparelho. O modo DEBUG `--qa-recorded-camera=<nome>` usa AVPlayer e AVPlayerItemVideoOutput para fornecer BGRA com o tempo do vídeo à mesma fila de inferência da captura. Não abre AVCaptureSession, não solicita câmera, não grava o vídeo novamente e não cria treino no Histórico.

A tela exibe **TESTE · vídeo gravado — não é câmera ao vivo**. Vídeo e prévia são a mesma fonte, sem áudio. Não é inferência offline antecipada, nem captura real das lentes; o resultado mede o pipeline com entrada gravada em tempo de reprodução. O ritmo do vídeo limita o FPS observado. `captureRunning: false` é esperado.

## Reprodução

1. Baixar recursos licenciados conforme `docs/assets-and-licenses.md`; manter mídia/modelos fora do Git.
2. `cd ios`, executar `xcodegen generate` e `pod install --deployment`; compilar o workspace com Xcode para o UDID físico `00008120-001468102EE2601E`.
3. Copiar clipes locais com `xcrun devicectl device copy to` para `Documents/QAPrivateClips/`, no app `com.fabiofigueiredo.ritmovis.dev`. Não apagar o contêiner. Os clipes enviados nesta sessão são `qa-squat-single.mp4` (Pexels 8837118, 1280×676) e `qa-squat-group.mp4` (Pexels 6740245, 1920×1080), ambos 25 fps e sem rotação embutida.
4. Iniciar o app com `--qa-recorded-camera=qa-squat-single.mp4`. Selecionar pelo botão na imagem. `--qa-recorded-select` é um gancho de QA que simula **uma seleção manual** após 0,5 s, escolhendo o candidato mais próximo do centro; não é seleção por gesto nem ground truth de identidade.
5. `--qa-gestures` permite experimentar o reconhecedor na fonte gravada. Os clipes de agachamento acima não são positivos anotados de palma/punho sustentados; não usá-los para afirmar sucesso dos comandos.
6. Ao terminar, copiar `Documents/qa-camera-diagnostics.json` para diretório privado com nome por execução antes do próximo teste. Verificar eventos, contagem e métricas; comparar o índice do Histórico antes/depois.

Somente nomes simples de arquivos locais são aceitos. A origem pode ser `QAPrivateClips` ou recurso do bundle. A captura de tela do XCTest deve conservar o aviso de origem, sem fabricação de overlays.

## Proteções e limitações

- No fim do arquivo, parar a produção de quadros e entregar o último resultado aceito antes de fechar o relatório. Parada manual/interrupção continua cancelável por token; não aplicar resultado antigo a sessão nova.
- Teste automatizado de Histórico cobre a política de exclusão; o teste UI cobre aviso, seleção, rotação e Parar, sem fingir que verificou persistência.
- Este modo é restrito a clipes normalizados sem rotação embutida. A composição que corrige MOV rotacionados no importador normal não está aplicada ao AVPlayerItemVideoOutput deste modo. Não afirmar paridade de orientação para qualquer vídeo do telefone.
- Modelo de pose é o baseline MediaPipe Lite/Full do caminho ao vivo, não o backend Vision disponível em importações. Não resolve a perda de identidade do box.
- Não mede latência de abertura das lentes, FPS de câmera, exposição, orientação da câmera frontal nem câmera preta no pareamento. Esses ensaios continuam separados.
- O Device Hub não respondeu ao controle visual nesta sessão. Capturas e relatórios do XCTest/Xcode são alternativas, não observação visual remota presumida.

## Resultado desta execução

**Continuação após desbloquear:** os clipes rodaram no iPhone físico e capturas reais foram obtidas por DVT. [Resultados, custo de gestos e pose misturada no grupo](qa-physical-recorded-input-2026-09-30.md). Os bloqueios abaixo descrevem a tentativa inicial; o perfil de runner permanece pendente, mas o bloqueio de tela foi resolvido pelo usuário.

- Aparelho confirmado por `devicectl`: **iPhone de fabio**, iPhone 15 físico, conectado. Os dois clipes foram copiados para a pasta privada do app.
- Build físico terminou com código 0; instalação no mesmo bundle terminou com sucesso. Índice do Histórico antes/depois da instalação permaneceu idêntico (SHA-256 `e4fcf7056cc8b82b4a263256c7d6196e7523fc8a3aa5764f30d00fa662b91ac3`). Isso prova preservação do índice durante instalação, não integridade de cada vídeo nem teste do modo em execução.
- O teste de interface físico foi **bloqueado antes da execução**: Xcode informou `No Accounts` e ausência do perfil `com.fabiofigueiredo.ritmovis.dev.uitests.xctrunner`. O perfil do app normal permitiu build/instalação; o runner é um requisito separado. Não rotular esse teste como aprovado.
- A tentativa inicial de iniciar o clipe por `devicectl` foi **recusada por telefone bloqueado**, erro `FBSOpenApplicationErrorDomain 7 / Locked`. Naquele momento não havia resultado, FPS, contagem nem captura desta versão no iPhone físico; a continuação após o desbloqueio está no relatório físico vinculado acima. Não reutilizar relatório antigo como nova execução.
- No simulador iPhone 15/iOS 27, a suíte final passou **134/134**, zero falhas/skips, em `Test-SquatCounter-2026.09.30_19-49-00--0300.xcresult` (117 núcleo + 10 UI + 7 hospedados). O teste UI da fonte gravada também passou isoladamente às 19:48 após acrescentar espera explícita pela orientação antes da captura. As capturas anteriores durante a animação de rotação foram substituídas como evidência visual por retrato/paisagem estáveis; capturas são **do simulador**, nunca do telefone.
- Capturas, `.xcresult` e cópias do Histórico continuam locais/privados, fora do Git. Revisão Astra após as correções: uso experimental sem bloqueadores de código remanescentes; teste físico, gestos à distância, M2 e beta não aprovados.

Próxima ação após a continuação: anotar ciclos e associação das articulações nos clipes testados, medir custo em ensaio sustentado e validar comandos deliberados. A seleção central de QA não prova identidade. Capturas DVT agora funcionam sem runner; testes automatizados de toque continuam exigindo conta/perfil apropriados, sem alterar o identificador do app nem apagar Histórico.
