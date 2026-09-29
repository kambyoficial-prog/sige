# 31 — Integridade financeira por escola e ano letivo

## Decisão de domínio

Uma obrigação financeira pertence a um ano letivo. Um pagamento é uma transação financeira independente e pode ser alocado a uma ou mais obrigações.

Portanto:

- `charges.academic_year_id` identifica o contexto da dívida;
- `payments` não precisa de um único ano proprietário;
- `payment_allocations` liga o pagamento à obrigação concreta;
- saldos históricos devem ser consultáveis por ano.

## Proteções

O banco agora valida:

- aluno e obrigação pertencem à mesma escola;
- obrigação e ano letivo pertencem à mesma escola;
- tipo de cobrança pertence à mesma escola;
- serviço do aluno pertence ao mesmo contexto escolar;
- transporte pertence à mesma escola do aluno;
- pagamento pertence à escola do aluno;
- alocação pertence à mesma escola entre pagamento e obrigação;
- recibo pertence à mesma escola do pagamento.

Também foi finalmente ligado o `validate_payment_allocation()` a um trigger de `payment_allocations`. A função existia, mas não estava anexada à tabela; uma função de validação não aplicada não constitui uma invariável.

## Histórico

`student_financial_balances` passou a agrupar por `school_id + student_id + academic_year_id`, permitindo distinguir saldo de anos diferentes.

## Segurança

As funções financeiras `SECURITY DEFINER` passaram a utilizar `search_path = ''`, com referências qualificadas, eliminando dependência de objetos resolvidos por search path.