# Anotação de grupo para treino e validação privados

O detector produz **observações**, não rótulos. Para os vídeos recebidos em 25/09, use os originais autorizados e as amostras privadas listadas em [QA do corpus](qa-private-videos-2026-09-25.md). Este documento descreve os rótulos que ainda faltam antes de treinar ou calibrar a associação temporal. O arquivo preenchido fica fora do Git.

## Unidade de anotação

- Por gravação: hash do original, duração, consentimento/limite de uso, sessão, câmera e qual é o objetivo (`um alvo` ou `todos os participantes`). Vídeos da **mesma sessão** pertencem ao mesmo split de ajuste ou aceitação.
- Por pessoa: `trackLabel` temporário dentro do clipe, roupa/posição inicial para revisão humana e papel `aluno`, `professor`, `visitante`, `imagem estática` ou `incerto`. Não incluir nome, rosto recortado ou identificação entre sessões.
- A cada 0,5–1 s e em todo cruzamento/oclusão: caixa normalizada `[x,y,w,h]`, `trackLabel`, visibilidade `visível`, `parcial`, `oculto` ou `fora`, e confiança do **anotador**. Uma observação duplicada do detector sobre a mesma pessoa precisa ser marcada como duplicata, não como novo aluno.
- Por tentativa: `startSeconds`, `endSeconds`, `trackLabel`, `completed`, e motivo quando incompleta. Para técnica, apenas observações objetivas separadas; não marcar “correto/seguro” sem profissional qualificado e protocolo próprio.

## Exemplo de estrutura, sem dados reais

```json
{
  "sourceSHA256": "<hash do vídeo privado>",
  "sessionID": "<identificador local não nominal>",
  "split": "adjustment-or-acceptance",
  "usageConsentReviewed": false,
  "people": [{"trackLabel": "A", "role": "aluno", "description": "posição/roupa não identificável"}],
  "observations": [{"timeSeconds": 0.0, "trackLabel": "A", "bboxXYWH": [0.1, 0.2, 0.2, 0.5], "visibility": "visível"}],
  "attempts": [{"trackLabel": "A", "startSeconds": 1.0, "endSeconds": 2.5, "completed": true}]
}
```

Dois revisores devem resolver divergências de ID/repetição antes de usar o arquivo como referência. Os eventos e caixas do app podem auxiliar a localizar erros, mas não podem ser copiados como verdade. Treinar um classificador `aluno vs professor` apenas por roupa, posição ou movimento de agachamento tende a aprender o cenário, não a matrícula do aluno; a identidade operacional requer confirmação/check-in. Use negativos explícitos, como o pôster do 7209 e pessoas que passam, e avalie o modelo em **outra sessão**. Reporte também abstenções e cobertura; um sistema que nunca conta pode ter zero troca de ID sem ser útil.

Para avaliação de associação, exporte uma amostra por instante anotado no contrato `TargetEvaluationInput` do núcleo Swift: `observability` (`observable`, `unobservable`, `absent`), `selectedTrackID` atribuído por revisor à caixa prevista (ou `null` se o app se absteve) e `creditedRepetition`. `targetTrackID` é temporário do clipe. `TargetEvaluator` devolve cobertura **nula** quando não há quadro observável; isso impede relatar 100% sem oportunidade de rastrear. Contagem e identidade são relatórios separados, combinados apenas no gate da beta.
