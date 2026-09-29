# Arquitetura

## Fundação executável

O SIGE usa pnpm workspaces + Turborepo e separa a aplicação web do domínio e dos adaptadores de infraestrutura.

### Next.js App Router

Server Components são o padrão. Client Components só entram quando há necessidade real de estado ou APIs do browser.

### Domínio independente

Regras de matrícula, avaliação, classificação e outros invariantes não dependem de React, Next.js ou Supabase. Isso permite testes determinísticos e evita que o banco seja a única representação das regras.

### Supabase como infraestrutura

Quando a integração começar, `packages/database` será a fronteira para PostgreSQL/Supabase. O domínio não importará diretamente o cliente Supabase.

### Segurança

Autorização não será confiada à UI. Backend e PostgreSQL/RLS serão fronteiras de segurança. Chaves privilegiadas ficam apenas em ambientes server-side.

### Histórico

Operações com impacto histórico usam estados e relações temporais. Matrículas, alocações, resultados publicados e pagamentos confirmados não são silenciosamente sobrescritos.

## Próxima camada

Transformar o modelo lógico já documentado em contratos PostgreSQL: enums, tabelas, constraints, índices, RLS e testes de autorização. Isso será preparado no repositório antes de qualquer aplicação a um projeto Supabase remoto.


## Bloco académico e operação

- [21 — Estrutura académica, turmas, grupos e horários](./21-academic-structure-and-timetable.md)
- [22 — Planeamento e distribuição de horários](./22-timetable-distribution-engine.md)
- [23 — Operações académicas: turmas, ofertas, docentes e transferência](./23-academic-operations-commands.md)
- [24 — Motor curricular](./24-curriculum-engine.md)

- [25 — Regras de avaliação e motor](./25-assessment-rules-and-engine.md)
- [26 — Ciclo temporal, fecho e histórico](./26-temporal-lifecycle-and-history.md)
- [27 — Hardening temporal das operações](./27-temporal-operations-hardening.md)

- [28–29 — Hardening do lifecycle e avaliação](./28-29-lifecycle-and-assessment-hardening.md)
- [30 — Integridade de escopo acadêmico](./30-academic-scope-integrity.md)
- [31 — Integridade financeira por escola e ano](./31-financial-scope-and-year.md)
- [32 — Segurança de funções privilegiadas](./32-privileged-function-security.md)
