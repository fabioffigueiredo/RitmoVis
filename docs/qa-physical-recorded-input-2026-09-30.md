# QA físico de fonte gravada — 30/09/2026

## O que foi executado

Após o proprietário desbloquear o **iPhone de fabio** (iPhone 15 físico), o app instalado no commit `dc06179` abriu por `devicectl`. Os clipes locais foram reproduzidos com `--qa-recorded-camera` e seleção manual simulada por `--qa-recorded-select`, no caminho de inferência da captura. O proprietário confirmou vídeo, esqueleto e aviso de fonte gravada na tela física. Não houve reinstalação, alteração de pesos/limiares nem captura das lentes nesta continuação.

Todos os resultados abaixo são **execuções curtas individuais**, não benchmark sustentado nem estimativa de acurácia. O tempo do clipe limita FPS. A seleção central automática do gancho de QA não é ground truth de identidade nem comando por gesto. `captureRunning: false` é esperado porque AVCaptureSession não foi iniciada.

| Fonte / modo | Quadros processados / descartados | FPS processados | Inferência média / p95 (ms) | Eventos | Quadros quase pretos |
|---|---:|---:|---:|---:|---:|
| Uma pessoa, Lite, sem gestos | 742 / 1 | 24,64 | 20,21 / 21,64 | 3 | 0 |
| Grupo, Lite, sem gestos | 396 / 34 | 22,64 | 24,89 / 34,27 | 0 | 0 |
| Uma pessoa, Lite + gestos | 565 / 178 | 18,85 | 31,83 / 56,81 | 3 | 0 |
| Grupo repetido, com capturas DVT | 380 / 50 | 21,78 | 26,13 / 37,06 | 0 | 0 |

No primeiro clipe, eventos em **12,28; 20,76; 29,20 s**. Com gestos ligados: **12,32; 20,76; 29,20 s**. Não houve evento de comando por gesto registrado; a seleção veio do gancho manual. O vídeo não contém positivos anotados dos comandos deliberados palma/punho sustentados. Ausência de comandos nesse clipe não valida taxa de falsos positivos ou reconhecimento à distância.

A seleção ocorreu em 0,52 s (0,56 s com gestos). O pipeline mantém uma espera de três segundos antes de consumir ângulos e exige ciclo iniciado em pé. Isso pode descartar um primeiro ciclo já em andamento; ainda é necessário anotar ciclos completos e comparar o ponto de início. **Três eventos não equivalem a três acertos nem provam uma falha versus as quatro contagens da análise offline anterior.** Nenhuma redução de limiar foi aplicada para fazer o resultado parecer correto.

Primeiro quadro gravado após o início: aproximadamente 372 ms no individual, 249 ms no grupo e 272 ms no individual com gestos. Não são tempos de abertura da câmera física. O ensaio com gestos teve mais descartes e maior p95; ordem dos testes, aquecimento e interferências não foram controlados, portanto repetir em condições equivalentes antes de atribuir todo o custo ao reconhecedor. Não foi realizado ensaio de dez minutos, nem teste Full nesta continuação.

## Capturas físicas e achado de grupo

Capturas PNG reais, feitas pelo serviço de diagnóstico DVT no mesmo UDID, sem montar vídeo, redesenhar overlays ou simular UI:

- `iphone-recorded-single.png`: tela física em retrato, tempo 00:29, contador 3, pose e aviso de vídeo gravado.
- `iphone-recorded-group-early.png`: tempo exibido 00:02, atleta central marcado; um ramo de braço alcança o punho do colega à esquerda.
- `iphone-recorded-group-late.png`: tempo exibido 00:09, atleta central ainda “Em foco”; um ramo de perna alcança a perna traseira do colega à esquerda.

As duas capturas de grupo sustentam **mistura de articulações/atribuição incorreta na pose exibida**. Não provam troca contínua de identidade nem isolam erro do modelo de um eventual desalinhamento temporal do overlay. “Em foco” é estado do rastreador, não certificação de que todas as articulações pertencem ao alvo. M2 segue sem aprovação.

Os colegas laterais aparecem fazendo afundos/avanços; o atleta central apresenta posição semelhante a agachamento na captura de 9 s. **Não classificar todo o clipe como exercício diferente nem explicar zero eventos apenas por esse motivo.** Rotular o movimento completo do alvo antes de interpretar a contagem.

## Ferramenta de captura e reprodução

Device Hub continuou sem responder. O runner UI físico do XCTest continua sem perfil; não foi corrigido nem usado. A alternativa de leitura de tela foi `pymobiledevice3` **11.20.2**, obtido do PyPI em ambiente isolado gerido por `uv`, sem modificar dependências do app/Xcode. Comando reproduzível:

```sh
uv tool run --from pymobiledevice3==11.20.2 pymobiledevice3 developer dvt screenshot \
  --udid <UDID_DO_IPHONE> --userspace <CAMINHO_PRIVADO.png>
```

O modo `--userspace` usa conexão de desenvolvimento existente e termina com o comando: não foram usados sudo, túnel nativo que poderia disputar remoted, servidor persistente, jailbreak, troca de pareamento ou ampliação pública de acesso. [CLI oficial do projeto](https://github.com/doronz88/pymobiledevice3/blob/master/docs/guides/cli-recipes.md) e [documentação de túneis](https://doronz88.github.io/pymobiledevice3/guides/ios17-tunnels/). Capturar somente com RitmoVis em primeiro plano. Isto captura a **tela**, não habilita as lentes nem fornece controle de toque/rotação.

JSON e PNG estão em `~/Library/Application Support/RitmoVis/qa-private/gestures-20260930`, fora do Git. Relatórios preservados como `single-physical-20260930-2008.json`, `group-physical-20260930-2010.json`, `single-gestures-physical-20260930-2012.json` e `group-capture-physical-20260930.json`. Os nomes identificam a execução, não necessariamente o segundo exato do relatório; usar `recordedAt` para a data efetiva.

Índice do Histórico após todos os clipes/capturas permaneceu idêntico ao anterior: SHA-256 `e4fcf7056cc8b82b4a263256c7d6196e7523fc8a3aa5764f30d00fa662b91ac3`. Não foi validada a integridade de cada vídeo antigo. Ao terminar, app reiniciado **sem flags QA**, no modo normal; nada do teste foi transformado em treino pessoal.

## Revisão e próximos gates

GPT‑6 Astra revisou resultados e imagens: reprodução experimental no telefone demonstrada; correção anatômica em grupo não resolvida. Próxima investigação deve alinhar as capturas ao PTS exato e revisar landmarks/confianças nos quadros vizinhos, distinguindo pose misturada de troca de identidade. Depois anotar ciclos do alvo central e do clipe individual, incluindo a espera inicial. Só então comparar solução de isolamento de pose/ROI com o baseline — essa arquitetura ainda não foi implementada.

Repetir gestos desligados/ligados em condições controladas, medir dez minutos e usar positivos/negativos reais dos comandos com anotação humana. Câmera ao vivo, gestos à distância, beta e Android continuam sem aprovação. A suíte automatizada de código não foi alterada nesta continuação; o último resultado permanece 134/134 no simulador, não 134 testes físicos.
