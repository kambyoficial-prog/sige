# SIGE — Threat model inicial

**Status:** accepted  
**Date:** 2026-09-29

## Ativos protegidos

1. Dados pessoais de alunos e encarregados.
2. Identificadores oficiais e BI.
3. Notas e resultados publicados.
4. Histórico de matrícula e transferências.
5. Obrigações e pagamentos.
6. Contas e permissões.
7. Documentos escolares.
8. Auditoria.

## Ameaças prioritárias

| Ameaça | Exemplo | Defesa |
|---|---|---|
| BOLA/IDOR | Professor consulta aluno de outra turma | RLS + escopo de assignment |
| Privilege escalation | Professor altera role | grants mínimos + RLS |
| Mass assignment | Request altera school_id/person_id | WITH CHECK + commands |
| Replay | Confirmação de pagamento repetida | idempotency key + unique constraint |
| Double payment allocation | Mesmo pagamento alocado acima do valor | locks + trigger/constraint |
| Grade tampering | Nota publicada alterada sem motivo | histórico + comando de correção |
| Cross-school contamination | Turma de escola A recebe disciplina de B | invariantes cross-row |
| Temporal overlap | Professor em duas aulas no mesmo horário | exclusion constraint |
| Secret leakage | service_role no browser | somente server-side |
| Audit tampering | Utilizador apaga eventos | revogação de INSERT/UPDATE/DELETE direto |
| Data loss | DELETE de aluno histórico | estados + DELETE revogado |
| Session abuse | token válido após mudança de acesso | política de sessão/revogação |

## Trust boundaries

`Browser -> Next server -> Supabase Auth -> PostgreSQL/RLS`

Nenhum limite substitui outro.

## Princípio de defesa em profundidade

Para operações críticas:

- UI: prevenção e feedback;
- aplicação: validação de command;
- Auth: identidade;
- RLS: autorização de linha;
- constraints: integridade estrutural;
- triggers: invariantes cross-row;
- audit: rastreabilidade;
- testes: regressão.

## Dados financeiros

Nunca confiar no saldo enviado pelo cliente.

O saldo é derivado de:
- charges;
- adjustments;
- confirmed payments;
- allocations;
- reversals.

O cliente envia intenção; o servidor/database calcula o estado.

## Dados académicos

A nota exibida numa pauta não deve ser a fonte primária da verdade.

A cadeia é:

`Assessment -> AssessmentResult -> RuleVersion -> AcademicResult -> Pauta`

A pauta é uma projeção/documento do estado académico.

## Publicação

Publicar é uma mudança de estado, não apenas `UPDATE score`.

O sistema deve registrar actor, timestamp e versão/regra utilizada.

## Referências

- Supabase RLS e grants.
- Supabase security-invoker views.
- PostgreSQL function security.
- Ed-Fi Student Academic Record e Enrollment domains.
