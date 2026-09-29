# SIGE — Workflow de matrícula

**Status:** accepted  
**Date:** 2026-09-29

## Separação de conceitos

Matrícula anual e colocação numa turma são estados diferentes:

`Student -> StudentEnrollment -> ClassPlacement`

Isso permite:
- matrícula pendente antes da formação de turmas;
- mudança de turma sem criar uma nova matrícula;
- transferência sem destruir o histórico;
- relatório anual independente da turma atual.

## Command 1 — enroll_student

Pré-condições:
- actor autenticado;
- conta ativa;
- permissão `enrollment.manage`;
- aluno pertence à escola;
- ano letivo pertence à mesma escola;
- ano letivo está OPEN;
- classe está ativa;
- não existe matrícula para aquele aluno naquele ano.

Efeitos:
- cria uma única matrícula anual;
- estado inicial ACTIVE;
- registra auditoria;
- registra resultado de idempotência.

## Command 2 — place_student_in_class

Pré-condições:
- matrícula ACTIVE/TRANSFERRED_IN;
- turma pertence à mesma escola;
- turma pertence ao mesmo ano;
- turma pertence à mesma classe;
- turma está OPEN/ACTIVE;
- capacidade não excedida.

Concorrência:
- a linha da turma é bloqueada durante o cálculo da ocupação;
- a exclusion constraint impede duas colocações sobrepostas do mesmo enrollment.

## O que não fazer

Não colocar:
- `class_group_id` em `students`;
- `class_group_id` como verdade em `student_enrollments`;
- saldo financeiro dentro de `students`;
- notas finais diretamente em `students`.

## Fluxo operacional

`Pessoa -> Student -> Enrollment -> Placement -> CourseParticipation`

A criação de CourseParticipation é uma operação académica subsequente à formação/abertura das ofertas, não uma duplicação de informação no cadastro do aluno.
