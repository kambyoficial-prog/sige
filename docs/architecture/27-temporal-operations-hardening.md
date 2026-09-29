# 27 — Hardening temporal do ano letivo

## Problema

O fecho de um ano letivo não pode proteger apenas avaliações e resultados. O ano é um contexto temporal que contém múltiplos agregados operacionais.

Sem uma barreira transversal, um comando privilegiado poderia continuar a alterar, depois do fecho:

- turmas;
- ofertas disciplinares;
- currículo configurado para o ano;
- matrículas;
- colocação de alunos;
- participações em disciplinas;
- atribuições de professores;
- diretores de turma;
- cargas horárias;
- períodos de avaliação.

Isso quebraria a propriedade fundamental do SIGE:

> **Ano fechado = histórico consultável + contexto operacional imutável.**

## Decisão

A partir da migration `20260929210000_temporal_operations_hardening.sql`, o PostgreSQL aplica uma segunda linha de defesa:

1. comandos de negócio devem validar o estado do ano;
2. triggers bloqueiam mutações diretas e também mutações realizadas por funções SECURITY DEFINER;
3. leituras históricas continuam permitidas;
4. uma futura correção pós-fecho deverá ser um comando específico, versionado e auditado.

## Agregados protegidos

A barreira cobre:

- `class_groups`
- `course_offerings`
- `curriculum_subjects`
- `curriculum_choice_groups`
- `teacher_workload_targets`
- `student_enrollments`
- `assessment_periods`
- `class_placements`
- `student_course_participations`
- `teacher_assignments`
- `class_group_leadership`

Avaliações, resultados de avaliação e resultados acadêmicos já possuíam guardas temporais anteriores.

## Idempotência

Também foi corrigido `generate_class_offerings`.

A operação estava a concluir o comando passando `p_request_hash` como payload do resultado. Isso não altera a criação da oferta, mas degrada o contrato de replay: uma chamada repetida poderia devolver metadados que representam o pedido em vez do resultado da operação.

O comando agora grava `result` no registro de idempotência.

## Regra de projeto

Não devemos reabrir um ano letivo para corrigir dados históricos.

O fluxo futuro deverá ser semelhante a:

`CLOSED` → `correction request` → `authorization` → `audited correction` → `new published/versioned state`

A implementação dessa correção é uma fase própria e não deve ser improvisada dentro de um CRUD administrativo.