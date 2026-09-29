# Ledger de resultados académicos

## Princípio

No SIGE, uma nota lançada não é automaticamente uma nota oficial.

A cadeia é:

AssessmentResult → AcademicResult(CALCULATED) → HOMOLOGATED → PUBLISHED

O primeiro guarda a evidência de avaliação. O segundo guarda o resultado derivado segundo uma versão normativa. O terceiro e quarto estados representam governança e publicação oficial.

## Por que persistir resultados derivados?

Calcular tudo dinamicamente em cada consulta perde propriedades importantes: não preserva exatamente o conjunto de inputs que originou uma pauta, dificulta auditoria e reprodução histórica, torna correções históricas ambíguas e mistura estado corrente com estado oficial.

Por isso cada academic_result guarda aluno, oferta/disciplina, ano letivo, período quando aplicável, tipo do resultado, valor interno, valor de apresentação, classificação, versão normativa, snapshot dos inputs, autores, timestamps e relação com resultado anterior quando houve recálculo.

## Versionamento

A regra 2022 é identificada por MZ-ES-2022-06-30.

Uma mudança de fórmula deve produzir uma nova versão de regra. Nunca se deve recalcular silenciosamente um resultado histórico usando a regra atual.

## Estados

### CALCULATED

Resultado matematicamente produzido pelo motor. Ainda não é publicação oficial.

### HOMOLOGATED

Resultado revisto e aceite pela autoridade académica definida pela escola.

### PUBLISHED

Resultado oficial disponibilizável para pauta, boletim e outros documentos. Depois de publicado, não deve ser recalculado diretamente.

### SUPERSEDED

Versão calculada anteriormente que deixou de ser a versão corrente antes da publicação. O registro não é apagado.

## Pauta

A pauta não é fonte de verdade. É uma projeção dos academic_results publicados, associada ao ano letivo, turma, disciplina, período, classe e aluno.

Essa separação é coerente com modelos SIS maduros: a documentação Ed-Fi separa Gradebook, Report Card e Student Transcript com finalidades distintas. Fonte: Ed-Fi Student Academic Record Domain, versão 6.

## Regra crítica

Nunca: Pauta → altera nota.

Sempre: Avaliação → Resultado → Homologação → Publicação → Pauta.

A pauta somente lê.

## Correções

Uma correção posterior deve identificar o resultado oficial, exigir motivo, identificar o autor, preservar o valor anterior, recalcular o resultado afetado, registrar auditoria e exigir nova homologação/publicação quando aplicável.

## Recuperação

Recuperação permanece como resultado/evento próprio. O sistema não deve substituir automaticamente a nota final original sem uma regra normativa confirmada que determine elegibilidade, fórmula, substituição, limites e impacto no estado final.
