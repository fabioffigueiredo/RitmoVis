# M0 — protocolo de anotação e avaliação

**Estado:** avaliador implementado; corpus real de 50 repetições e ensaio de 10 minutos **pendentes**. O JSON em `ios/Fixtures` é sintético e serve somente para testar a ferramenta.

Em 24/09, 12 vídeos do Histórico do iPhone foram copiados para uma pasta privada fora do repositório. Os números de repetições do Histórico são saída do aplicativo, **não ground truth**. Anotar os ciclos vendo os arquivos originais, manter sessões usadas para ajuste separadas das usadas no gate e não declarar M0 concluído até alcançar o volume e os testes físicos previstos.

## Coleta

1. Use apenas gravações autorizadas e registre aparelho, câmera, ângulo, iluminação, resolução, modelo Lite/Full e versão do app. Não coloque vídeos pessoais no Git.
2. Para cada tentativa, marque no tempo do **arquivo-fonte** `startSeconds` (início da descida) e `endSeconds` (retorno a uma postura em pé ou fim da tentativa). Marque `completed: false` quando não houver ciclo completo. Uma segunda pessoa deve revisar casos ambíguos, mantendo o desacordo anotado.
3. Exporte do app os horários dos eventos `+1` relativos ao mesmo arquivo. Não misture horário de relógio, uptime do aparelho ou instante do replay com o PTS da mídia.
4. Defina `toleranceSeconds` **antes** de olhar os erros. Sugestão inicial de protocolo: 0,5 s, a confirmar com a frequência de quadros e a concordância entre anotadores. A escolha não muda depois de ver o resultado.

## Rodar

```sh
cd ios
swift test
swift run ritmovis-eval Fixtures/evaluation-synthetic.example.json
```

Para cada clipe real, copie o esquema JSON para um local privado, substitua `clipID`, anotações e `detectedAtSeconds`, e rode o mesmo comando. A ferramenta ordena eventos no tempo, faz associação um-para-um dentro da tolerância e apresenta TP, FP, FN, falsos positivos em tentativas incompletas, tempos de eventos extras/perdidos e erro temporal médio. Ela rejeita intervalos sobrepostos ou tempos inválidos. Precisão e recall ficam `null` quando não existe denominador; nunca transforme um clipe vazio em “100% de acerto”.

Compare resultados **por clipe, câmera e condição**, não apenas uma média agregada. Para a meta M0, mantenha separados o protocolo controlado e os cenários difíceis. O avaliador não decide se o movimento é tecnicamente correto ou seguro.
