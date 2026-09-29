# 23 — Operações académicas: turmas, ofertas, docentes e transferência

## Estado

**Decisão:** fundação operacional aceite para a gestão académica da fase 1.

Esta camada transforma a estrutura académica em operações transacionais. A regra central é:

> O frontend não decide invariantes académicas; os comandos de domínio e o PostgreSQL fazem isso.

## 1. Turma

A turma é uma unidade operacional anual:

`school + academic_year + grade + pathway? + section`

A **section** identifica a letra/código operacional da turma.

A **pathway** identifica a organização curricular, quando aplicável.

Portanto, a combinação:

- 11.ª A — Grupo A
- 11.ª A — Grupo B

pode existir simultaneamente. A unicidade da secção passa a considerar o pathway.

Isto corrige uma ambiguidade estrutural importante da primeira versão do modelo.

## 2. Ciclo, área e turma continuam separados

A cadeia permanece:

`education_level → academic_cycle → grade_level → academic_pathway? → class_group`

Não usamos o nome da turma para inferir currículo.

Não usamos A/B/C como enumeração fixa no código.

## 3. Currículo → oferta

O currículo é a definição académica.

A oferta é a concretização dessa definição para uma turma no ano letivo.

`curriculum_subject → course_offering → class_group`

A operação `generate_class_offerings` lê o currículo configurado para:

- ano letivo;
- escola;
- classe;
- pathway.

Para uma turma com pathway, entram:

1. disciplinas comuns;
2. disciplinas específicas do pathway.

Para uma turma sem pathway, entram apenas as disciplinas comuns.

Uma disciplina já existente não é duplicada.

Isto evita que a secretaria tenha de reconstruir manualmente a lista curricular de cada turma.

## 4. Professor → oferta

A relação é:

`teacher → teacher_assignment → course_offering → class_group`

Assim um professor pode ensinar várias turmas.

Exemplo:

- Matemática — 8.ª A;
- Matemática — 8.ª B;
- Matemática — 9.ª A.

Não existe `teacher.class_id`.

A atribuição é temporal. Uma substituição ou mudança de docente não apaga a anterior.

A mesma pessoa também pode ter várias atribuições simultâneas em ofertas diferentes. O conflito de horário é tratado pelo calendário, não pela relação administrativa de atribuição.

O banco impede apenas duplicação temporal do mesmo professor na mesma oferta.

## 5. Criação e edição de turmas

Foram definidos comandos:

- `create_class_group`
- `update_class_group`
- `close_class_group`

Todos:

- autenticam o actor;
- verificam a escola;
- verificam permissão;
- validam contexto académico;
- usam idempotência;
- registam auditoria.

As tabelas não ficam abertas a INSERT/UPDATE/DELETE genérico pelo cliente autenticado.

## 6. Fecho de turma

Fechar uma turma é diferente de apagar.

O registo permanece para:

- histórico;
- pautas;
- relatórios;
- auditoria;
- histórico do aluno;
- reconstrução do ano letivo.

A eliminação física não faz parte do fluxo operacional normal.

## 7. Transferência entre turmas

A transferência interna não altera retroativamente a matrícula.

O aluno continua no mesmo `student_enrollment`.

O que muda é a relação temporal:

`class_placement`

Exemplo:

- 8.ª A: 01/02 → 14/05
- 8.ª B: 15/05 → fim do ano

A mesma lógica é aplicada às participações nas disciplinas.

As participações antigas são encerradas e novas participações são criadas para as ofertas da turma destino.

Assim o SIGE consegue responder historicamente:

> Em que turma o aluno estava em determinada data?

e:

> Em que oferta/disciplina o aluno estava inscrito nesse período?

## 8. Por que isto é importante

Modelos simplificados costumam fazer:

`student.class_id = X`

Isso perde:

- transferências;
- datas;
- histórico;
- professores diferentes;
- alterações curriculares;
- reconstrução de pautas antigas.

O SIGE mantém relações temporais.

Essa decisão é consistente com modelos SIS maduros: Ed-Fi separa Course, CourseOffering, Section e as associações de Staff e Student às sections. O padrão também trata explicitamente transferência de estudante entre sections e entrada/saída de staff de uma section. citeturn1search0turn1search1

## 9. Horário continua separado

A atribuição administrativa do professor não é o horário.

Um professor pode estar atribuído a cinco turmas e, posteriormente, ter essas aulas distribuídas em períodos diferentes.

O horário responde:

`dia + período + turma + oferta + professor + sala`

As constraints de horário continuam sendo a última barreira contra colisões.

## 10. Segurança

Os comandos são `SECURITY DEFINER` apenas quando necessário para executar a operação transacional com privilégios controlados.

O `search_path` é fixado em vazio e as relações são referenciadas explicitamente.

As views destinadas ao frontend usam `security_invoker`, permitindo que as políticas RLS das tabelas subjacentes continuem relevantes. A documentação atual do Supabase recomenda precisamente essa abordagem para views expostas. citeturn0search5turn0search6

## 11. Próxima consequência arquitetural

Agora já existe uma cadeia operacional coerente:

`Ano letivo
  ↓
Currículo
  ↓
Classe
  ↓
Turma
  ↓
Oferta de disciplina
  ↓
Professor
  ↓
Aluno
  ↓
Participação disciplinar
  ↓
Avaliação
  ↓
Resultado académico
  ↓
Pauta`

O próximo grande domínio não deve ser uma página visual.

É a **configuração curricular e académica completa**, incluindo:

- disciplinas e códigos;
- currículo por ano/classe;
- pathway;
- disciplinas obrigatórias/opcionais;
- carga semanal;
- períodos de avaliação;
- regras de progressão;
- exames;
- recuperação;
- geração oficial da pauta.

Só depois disso a UI de “Turmas” terá um contrato de domínio suficientemente estável para ser construída sem retrabalho.
