# 44 — F5: camada de comandos de operações

F5 já possuía o modelo PostgreSQL de calendário, salas, períodos, horários, sessões e frequência. Esta etapa fecha a fronteira de escrita.

## Comandos

- `create_room`
- `create_schedule_period`
- `upsert_school_calendar_day`
- `create_schedule_entry`
- `set_schedule_entry_status`

Todos exigem autenticação, capacidade `operations.manage`, idempotência e auditoria.

## Invariantes

A criação do horário continua delegada ao PostgreSQL para garantir:

- turma sem duas aulas no mesmo período;
- professor sem duas aulas no mesmo período;
- sala sem duas aulas no mesmo período;
- oferta compatível com turma/ano;
- atribuição compatível com professor/oferta;
- período e sala pertencentes à escola;
- vigência dentro do ano letivo;
- vigência compatível com a atribuição docente.

A UI poderá apresentar conflito antecipadamente, mas nunca será a autoridade da regra.

## Ciclo

`DRAFT → ACTIVE → ENDED`

Cancelamentos são explícitos. Um horário ativo não é editado silenciosamente: uma alteração cria uma nova entrada e altera o estado da anterior.

## Livro de ponto

A unidade operacional é `class_session`. `attendance_records` pertence à sessão; não criamos um agregado genérico de faltas.

## Estado de F5

A camada de domínio/comandos está implementada. Ainda faltam as superfícies de UI, browser QA e execução da suíte PostgreSQL contra um ambiente SIGE autorizado.
