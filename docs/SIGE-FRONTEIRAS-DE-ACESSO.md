# SIGE — Fronteiras de acesso entre Direção, Secretaria, Professores e Alunos

## Princípio

O SIGE usa duas camadas complementares:

1. **Navegação por papel** — evita expor operações que não pertencem ao perfil.
2. **RLS e comandos no banco** — são a autoridade de segurança; esconder um menu nunca é considerado autorização.

A regra é: **permissão define a capacidade; vínculo define o alcance**.

## Matriz funcional

| Área | Direção | Secretaria | Professor | Aluno |
|---|---|---|---|---|
| Alunos | escola | escola | alunos das suas turmas/ofertas | próprio |
| Professores | escola | escola | próprio contexto | não |
| Matrículas/inscrições | gerir/consultar | gerir/consultar | não | próprio estado quando disponibilizado |
| Turmas | escola | escola | turmas onde leciona | turma própria |
| Disciplinas/ofertas | escola | escola | ofertas atribuídas | ofertas em que participa |
| Notas/resultados | escola | consulta | próprias ofertas/alunos | próprios resultados |
| Pautas | escola | consulta | contexto pedagógico atribuído | não |
| Exames | gestão conforme permissão | consulta quando aplicável | não | resultados próprios quando publicados |
| Horários | escola | escola | próprio horário | próprio horário |
| Livro de ponto | gestão/consulta | gestão/consulta | próprio livro de ponto | não |
| Financeiro | conforme permissão | não | não | não |

## Regras de escopo

### Direção

A Direção é um papel de gestão escolar. Quando possui a permissão correspondente, pode consultar ou gerir o domínio da escola.

A RLS continua vinculada a school_id; portanto, uma conta de Direção de uma escola não atravessa para outra escola.

### Secretaria

A Secretaria opera o ciclo administrativo e escolar: pessoas, matrícula/inscrição, turmas, horários, professores, encarregados e relatórios permitidos.

Não recebe automaticamente acesso financeiro apenas por ser Secretaria.

### Professor

Professor não é um operador escolar global.

O alcance pedagógico é derivado das atribuições ativas:

Professor → teacher_assignment → course_offering → turma + disciplina

Consequências:

- consulta apenas as turmas onde possui uma atribuição ativa;
- consulta os alunos pertencentes ao seu contexto pedagógico;
- não recebe automaticamente BI/identificadores, dados de encarregados ou outros dados administrativos do aluno;
- lança avaliação apenas nas próprias ofertas, segundo assessment.own.enter;
- consulta resultados apenas das suas ofertas/alunos;
- vê o próprio horário;
- não administra matrícula, cadastro geral, financeiro ou contas escolares.

A atribuição tem janela temporal (starts_on / ends_on), portanto uma atribuição encerrada deixa de conceder acesso operacional.

### Aluno

Aluno não recebe acesso escolar global.

O alcance é derivado da própria identidade:

Conta → pessoa → aluno → matrícula/colocação → turma → participações

Consequências:

- vê o próprio perfil académico permitido;
- vê a própria matrícula e colocação;
- vê a própria turma;
- vê apenas as disciplinas/ofertas em que participa;
- vê apenas os próprios resultados;
- vê o próprio horário;
- não vê outros alunos, professores como diretório, finanças, matrícula de terceiros ou ferramentas administrativas.

## Integrações entre áreas

### Direção → Secretaria

A Direção define/autoriza o domínio institucional; a Secretaria executa as operações administrativas permitidas.

Os dois perfis partilham dados da escola, mas não necessariamente as mesmas ações. A diferença é expressa por permissões como enrollment.manage, operations.manage, staff.manage e academic_year.manage.

### Secretaria → Professores

A Secretaria cadastra e mantém o vínculo administrativo do professor. A atribuição pedagógica liga depois o professor às ofertas disciplinares.

O cadastro civil/profissional não cria automaticamente um e-mail institucional nem uma conta de acesso.

### Secretaria/Direção → Alunos

A matrícula e a inscrição estabelecem o vínculo anual. A colocação em turma estabelece o contexto pedagógico. As participações em ofertas determinam quais disciplinas o aluno realmente possui.

Isso evita usar apenas student_id como autorização global.

### Professor → Aluno

O professor não recebe acesso por simplesmente existir na escola.

O acesso nasce de uma atribuição ativa a uma oferta que, por sua vez, está ligada à turma. O aluno só aparece no contexto pedagógico quando existe a cadeia correspondente.

### Aluno → resultados

Os resultados publicados permanecem ligados ao student_id e à oferta. A política de leitura exige que o aluno seja o próprio titular do resultado.

## Implementação

A migração 20260930060000_role_scoped_access_boundaries.sql adiciona funções privadas para:

- identificar o aluno atual;
- identificar o professor atual;
- verificar atribuição ativa do professor a uma oferta;
- verificar participação do aluno numa oferta;
- verificar acesso do aluno a uma turma;
- verificar acesso do professor a uma turma;
- centralizar a leitura de registos de aluno.

As políticas de leitura foram endurecidas para students, people, student_enrollments, class_placements, class_groups, course_offerings, teacher_assignments, student_course_participations, assessment_definitions, assessments, assessment_results, academic_results e horários.

As funções privadas utilizam SECURITY DEFINER apenas como helpers controlados de autorização, com search_path vazio e EXECUTE concedido apenas a authenticated.

## Regra de arquitetura

Nunca implementar autorização apenas no frontend.

O frontend pode esconder uma operação; o banco deve impedir a operação quando o contexto não for legítimo.

A fronteira final é:

**Identidade → papel → permissão → escola → vínculo funcional → recurso.**
