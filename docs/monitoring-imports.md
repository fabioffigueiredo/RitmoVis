# Monitoramento dos testes de importação — 26/09/2026

## Sessão de desenvolvimento

O proprietário autorizou acompanhar testes que ele próprio inicia importando vídeos no iPhone de fabio, e pediu acesso ao Xcode/Device Hub pelo computador, sem navegador. O workspace atual foi aberto no Xcode e o destino foi corrigido para **iPhone de fabio**, UDID `00008120-001468102EE2601E`. O aparelho estava conectado por cabo, mas despareado; `devicectl manage pair` refez o pareamento e o acesso ao contêiner do app funcionou. O acesso de interface ao Device Hub excedeu o tempo de resposta; isto impede afirmar que a tela do telefone está sendo vista remotamente. Os relatórios são lidos pelas ferramentas de dispositivos do Xcode.

O build Debug iniciado com `--qa-monitor-imports` continua permitindo importação por Fotos/Arquivos e escolha manual do aluno. O sinalizador só habilita diagnóstico; não escolhe alvo ou muda o modelo. Sem ele, esta coleta adicional fica desativada. Fechar o processo e reabrir o app pode perder o sinalizador; se os arquivos pararem de atualizar, confirmar isso antes de reiniciar qualquer teste.

O argumento foi configurado no editor de Scheme do Xcode (Run → Arguments), na máquina do proprietário. Em seguida, o botão Run executou o build final no destino físico, e a barra do Xcode confirmou `Running SquatCounter on iPhone de fabio`. Este ajuste de sessão fica na configuração gerada/local; XcodeGen pode recriá-la. Não ativar coleta como padrão de produto.

## Evidência salva localmente

`Documents/QAMonitoring/` contém JSON com nomes UUID imutáveis e uma cópia `latest.json`. Cada importação usa o mesmo `analysisID` nos eventos e nas reanálises após escolha de aluno. Tipos de registro:

- `analyzing-video` e `analyzing-selection`: início, fonte e, quando disponível, instante da escolha no vídeo.
- `first-pass-completed` e `selection-completed`: modelo efetivamente usado, eventos, contagens, desempenho e traço por quadro (candidatos, decisão, ângulo e centro do tronco quando disponível).
- `import-failed`, `analysis-failed`, `analysis-cancelled`, `selection-refused` e `calibration-refused`: mensagem e etapa que permitem localizar a tentativa.

Os traços não contêm assinatura de cor, reconhecimento facial nem identidade nominal. Vídeos e relatórios pessoais permanecem fora do Git. Os vídeos importados não são copiados pelo monitor automaticamente; uma cópia privada para investigar uma falha deve ser feita apenas se necessária.

## Acompanhamento da sessão

Automação de acompanhamento nesta conversa: `acompanhar-testes-de-v-deo-do-ritmovis`, a cada 5 minutos, até o fim de 26/09 no horário de São Paulo. É acompanhamento periódico de relatórios, não observação contínua da tela. Encerrar quando o proprietário terminar os testes. Não reinstalar, reiniciar, trocar detector ou cancelar análises durante os testes do proprietário.

Área privada de trabalho: `/Users/fabiofigueiredo/Library/Application Support/RitmoVis/qa-private/monitor-20260926/`. Ignore o baseline de preparação com `analysisID` `D99069D4-757B-4122-8016-1B80392C7916`. Arquivos já copiados servem como controle de deduplicação; pule `latest.json` na coleta dos registros imutáveis. Compare resultados do primeiro passe e da seleção, sem tratar ausência de seleção em grupo como falha. Conte apenas o trecho após a escolha ao calcular cobertura. Quadros sem ângulo, pausas e zero repetições precisam de contexto humano; não equivalem automaticamente a erro.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device info files \
  --device 00008120-001468102EE2601E --domain-type appDataContainer \
  --domain-identifier com.fabiofigueiredo.ritmovis.dev \
  --subdirectory Documents/QAMonitoring --no-recurse --timeout 15
```

Copiar cada arquivo novo com `device copy from`, fonte `Documents/QAMonitoring/<UUID>.json` e destino na área privada. Só avisar o proprietário com resultado novo relevante, falha observada ou pedido de ação específico. Sem novidades, aguardar a próxima execução. Para validar troca de identidade ou contagem errada, precisar do aluno escolhido, instante e contagem esperada, além de revisar o vídeo autorizado; os próprios traços não constituem verdade humana.

## Preparação verificada

Build assinado iOS aprovado e 54/54 testes do núcleo aprovados em 26/09. No iPhone físico, o clipe de referência com `--qa-monitor-imports --qa-clip-lite` criou evento de início e relatório completo em arquivos diferentes. O relatório registrou 743 quadros e 4 eventos; isto verifica a coleta, não precisão geral. Logs locais: `/tmp/ritmovis-import-monitor-build.log` e `/tmp/ritmovis-import-monitor-core.log`.
