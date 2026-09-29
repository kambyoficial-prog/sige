# SIGE — Contratos de comandos

**Status:** accepted  
**Date:** 2026-09-29

Os comandos são a fronteira de aplicação para operações que representam intenção de negócio.

## Envelope

Todo comando mutável deve carregar:

- `commandId`: UUID único da tentativa lógica;
- `actorId`: identidade autenticada;
- `schoolId`: contexto institucional;
- `idempotencyKey`: obrigatório para operações externas/repetíveis;
- `expectedVersion`: quando optimistic concurrency for aplicável;
- `reason`: obrigatório em correções, reversões e exceções.

## Resultado

O command handler retorna:

- entidade/result ID;
- novo estado;
- versão;
- audit event ID;
- idempotency status.

Nunca retorna um "sucesso" desacoplado da transação.

## Commands prioritários

### Enrollment
`EnrollStudent`
`PlaceStudentInClass`
`TransferStudent`
`WithdrawStudent`

### Academic
`CreateAssessment`
`SaveAssessmentResults`
`PublishResults`
`CorrectPublishedResult`
`CloseAssessmentPeriod`

### Finance
`IssueCharge`
`ConfirmPayment`
`AllocatePayment`
`AdjustCharge`
`ReversePayment`

### Academic year
`OpenAcademicYear`
`CloseAcademicYear`

## Não-negociáveis

1. Authorization é validada dentro do command, não pelo caller.
2. Toda mutação crítica é atómica.
3. Idempotência é verificada dentro da mesma transação.
4. Conflitos de concorrência produzem erro explícito.
5. Histórico financeiro/académico não é apagado.
6. Auditoria é criada na mesma transação.
7. O command não aceita `schoolId`, `personId`, `teacherId` ou equivalentes cegamente como autoridade; estes IDs são validados contra o contexto do actor e do recurso.

## Transação

O padrão é:

`authorize -> lock/validate -> mutate -> audit -> persist idempotency result -> commit`

Não:

`authorize -> mutate -> audit later`

Se a auditoria falhar, a operação crítica deve falhar juntamente com ela.

## Concurrency

Use:
- unique constraints para unicidade;
- exclusion constraints para ranges;
- row locks para agregados financeiros;
- optimistic versioning onde edição concorrente de formulário seja comum;
- idempotency keys para retries.

Não usar "check-then-insert" como mecanismo exclusivo de integridade.

## Referências

Supabase recomenda separar grants de RLS e proteger funções, especialmente SECURITY DEFINER. PostgreSQL deve ser usado para invariantes que precisam permanecer verdadeiras independentemente do cliente.
