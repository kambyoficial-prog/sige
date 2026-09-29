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

## Sessão de aula e livro de ponto

A unidade operacional é `class_session`. `attendance_records` pertence à sessão; não existe um agregado genérico de faltas.

O fluxo agora é:

```
schedule_entry
  ↓
open_class_session
  ↓
class_session (OPEN)
  ↓
record_session_attendance
  ↓
close_class_session
  ↓
class_session (CLOSED)
```

A abertura valida a entrada de horário, ano letivo, vigência, dia da semana e calendário escolar. A autorização é avaliada contra `operations.manage` ou, para docentes, `attendance.own.manage` e a própria atribuição.

Enquanto a sessão está `OPEN`, o lançamento pode ser substituído pelo comando de frequência para o mesmo aluno. Depois de `CLOSED`, a escrita operacional é bloqueada.

A fronteira de escrita foi endurecida: `authenticated` não possui mais INSERT/UPDATE/DELETE direto em `class_sessions` ou `attendance_records`. A aplicação usa exclusivamente os comandos auditados e idempotentes.

As projeções `class_session_directory` e `class_session_roster` são `security_invoker` e servem a UI operacional sem se tornarem fontes de verdade.

## Estado de F5

A camada de domínio/comandos e o primeiro fluxo operacional completo estão implementados. Ainda faltam a distribuição completa de horários por professor/aluno, QA de browser e execução da suíte PostgreSQL contra um ambiente SIGE autorizado.
