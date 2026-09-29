# SIGE — Fronteira de comandos de domínio

**Status:** accepted  
**Date:** 2026-09-29

## Objetivo

O SIGE não deve modelar operações críticas como uma sequência arbitrária de chamadas CRUD feitas pela interface.

Uma operação de negócio deve ser tratada como um **command**:

`command + actor + context -> atomic state transition`

A aplicação coordena o processo; PostgreSQL garante invariantes; RLS garante o perímetro de acesso.

## Operações críticas

### Secretaria

- `enroll_student`
- `place_student_in_class`
- `transfer_student`
- `withdraw_student`
- `close_enrollment`

### Pedagógico

- `create_assessment`
- `save_assessment_results`
- `publish_results`
- `correct_published_result`
- `close_assessment_period`

### Finanças

- `issue_charge`
- `confirm_payment`
- `allocate_payment`
- `adjust_charge`
- `reverse_payment`
- `issue_receipt`

### Direção

- `close_academic_year`

## Regra de atomicidade

Uma operação que altera múltiplas entidades deve concluir completamente ou não produzir efeito parcial.

Exemplo de matrícula:

1. validar actor e escola;
2. validar pessoa;
3. criar/associar Student;
4. criar StudentEnrollment;
5. validar ano/classe;
6. criar ClassPlacement;
7. criar participações académicas necessárias;
8. gerar eventos de auditoria;
9. commit.

Se uma etapa falhar, todas as alterações da operação são revertidas.

## Idempotência

Comandos externos que podem ser repetidos devem aceitar uma chave idempotente.

Exemplo:

`confirm_payment(idempotency_key)`

A mesma chave não pode produzir dois pagamentos confirmados.

Isto é especialmente importante para:
- browser retry;
- rede móvel instável;
- double-click;
- reenvio de request;
- workers;
- integrações futuras.

## Concurrency

Não confiar em:

`SELECT balance -> calcular -> INSERT`

sem proteção.

Para dinheiro e outras sequências críticas:
- constraints;
- row locks quando necessário;
- transações;
- funções determinísticas;
- operações reversíveis em vez de DELETE.

Para horários, o PostgreSQL já usa exclusion constraints para impedir sobreposição temporal; isso é mais forte que uma verificação prévia feita apenas pela aplicação.

## Autorização

O command deve validar:

1. identidade Auth;
2. conta SIGE ativa;
3. Person;
4. escola;
5. role/permission;
6. escopo do recurso;
7. estado atual da entidade;
8. transição permitida.

Uma UI escondendo um botão nunca constitui autorização.

## Estado e transições

Estados devem ter uma máquina explícita quando a transição tiver significado operacional.

Exemplo:

`DRAFT -> OPEN -> PUBLISHED -> SUPERSEDED`

Não permitir transições arbitrárias como:

`CANCELLED -> PUBLISHED`

sem comando de recuperação explicitamente definido.

## Auditoria

Auditar o **comando**, não apenas o clique da interface.

Um evento deve responder:
- quem;
- quando;
- escola;
- qual operação;
- qual entidade;
- qual estado anterior;
- qual estado novo;
- motivo;
- request/correlation id.

## O que fica fora do domínio

O domínio não deve importar:
- React;
- Next.js;
- Supabase client;
- componentes UI;
- cookies;
- browser APIs.

Isso permite testar regras sem levantar a aplicação.

## Referências

- Ed-Fi Student Academic Record: GradebookEntry, Grade, ReportCard e CourseTranscript representam responsabilidades diferentes no ciclo académico.
- PostgreSQL exclusion constraints protegem sobreposição temporal.
- Supabase RLS permanece como perímetro de autorização no banco.
