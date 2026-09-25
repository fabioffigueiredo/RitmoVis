# Testar vídeos recebidos no iPhone

## Fluxo para o proprietário

1. Peça à pessoa que envie um arquivo de vídeo com corpo inteiro visível, boa luz e autorização para teste privado. Pode ser vertical ou horizontal; anote se há outras pessoas no quadro e qual delas deveria ser analisada. Evite vídeos com crianças, clientes ou terceiros sem consentimento.
2. Salve o arquivo recebido em **Arquivos** ou **Fotos** do iPhone. O RitmoVis não recebe links nem uploads por servidor nesta versão.
3. Abra **RitmoVis → Treino → Analisar vídeo recebido**. Para um grupo, habilite **Apple Vision para vídeos com grupo (experimental)** antes de abrir Arquivos/Fotos. Espere a análise local terminar. No replay pausado, escolha um quadro em que o aluno esteja visível e toque **Selecionar** sobre ele. A seleção recalcula os eventos usando poses em cache, sem recriar o player nem executar inferência novamente. O trecho anterior à seleção não recebe contagens.
4. Para um teste rápido do build privado, toque em **Ver teste: uma pessoa** ou **Ver teste: três pessoas**. Esses botões aparecem somente se os clipes licenciados estiverem incluídos no build de desenvolvimento; não são necessários para importar seus arquivos.
5. Se a estimativa de ângulo não alcançar o limiar padrão, pause em um quadro **realmente em pé** e habilite **Usar este quadro em pé como referência (experimental)** antes de selecionar. A opção é desligada ao mudar o quadro, importar outro vídeo ou pedir nova seleção. Não use referência agachada. O app pode rejeitar a referência por baixa confiança; isso não é uma avaliação de técnica.
6. Registre aparelho, detector efetivo (Vision ou MediaPipe Lite/Full), calibração, origem/consentimento, número manual de repetições de cada pessoa, falsos positivos, perdas, posições e o motivo de abstenção. Não use o número automático como anotação de referência.

## Interpretação e limites

- O vídeo é copiado temporariamente para o contêiner do app e analisado **antes** da reprodução; não é salvo como treino concluído nem enviado a um servidor.
- O leitor passou a aceitar quadros verticais e a aplicar rotação embutida; um fixture curto H.264/8-bit passou no simulador em 25/09. Os originais 4K/10-bit, especialmente um vídeo longo, ainda exigem teste de decodificação, memória e duração no iPhone físico. Formato corrompido ou sem faixa de imagem deve continuar gerando erro, nunca resultado fabricado. Ver [corpus privado](qa-private-videos-2026-09-25.md).
- Em arquivo com mais de uma pose detectada em qualquer quadro, **todas as contagens provisórias são descartadas** até o usuário selecionar um alvo. Após o toque, o app recalcula o cache, mas só conta a partir do quadro escolhido. Se o alvo não for encontrado, cruzar com outra pessoa ou ficar ambíguo, o app se abstém/pede nova seleção. Uma nova seleção começa uma análise independente: não soma o total da seleção anterior. Contagem zero pode refletir perda de rastreamento ou limiar incompatível, não ausência de movimento. Mesmo se só uma pose for detectada, isso não prova que o vídeo tenha apenas uma pessoa.
- As caixas são observações por quadro, **não IDs persistentes**. Uma pessoa que passa, inclusive professor, pode aparecer como candidata. O app ainda não sabe distinguir aluno inscrito de visitante.
- Os clipes importados não entram no Histórico de treino. Arquivos temporários não são um repositório de evidência e podem ser removidos pelo sistema; mantenha o original e as anotações consentidas fora do Git.

## Matriz de cenários a coletar

| Cenário | Esperado nesta etapa |
|---|---|
| Um aluno, corpo inteiro, câmera estável | Pose, contagem e replay; comparar à anotação humana |
| Duas ou mais pessoas visíveis | Detectar múltiplas candidatas e não atribuir contagem antes da seleção; avaliar identidade após o toque |
| Professor demonstrando ao lado do aluno | Não assumir que quem se move é o aluno |
| Pessoas cruzando/trocando de posição | Testar seleção offline e ao vivo; medir trocas de ID, cobertura e abstenções |
| Oclusão, saída/reentrada, enquadramento parcial | Registrar períodos sem avaliação, sem completar repetição parcial de outra pessoa |
| Vídeo vertical/com orientação embutida | Analisar com quadro e overlay alinhados; testar formato/resolução real no aparelho |

Antes de reivindicar precisão ou abrir beta, completar M0 (50+ ciclos anotados e 10 minutos ao vivo), M2 (identidade/abstenção/cobertura em vídeos reais independentes) e QA físico. Veja `docs/qa-status.md` e `roadmap.md`.
