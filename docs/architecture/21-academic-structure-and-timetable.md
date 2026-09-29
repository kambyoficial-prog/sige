# 21 — Estrutura académica, turmas, grupos e horários

## Estado

**Decisão:** aceite como fundação académica do SIGE.  
**Escopo:** Ensino Secundário na fase 1, com arquitetura preparada para Centro Infantil e Ensino Primário.

## 1. Regra nacional de estrutura

O Plano Curricular do Ensino Secundário do Ministério da Educação estabelece dois ciclos:

- **1.º ciclo:** 7.ª, 8.ª e 9.ª classes;
- **2.º ciclo:** 10.ª, 11.ª e 12.ª classes.

A aplicação não deve representar isto apenas como texto. O domínio passa a ter:

`education_level → academic_cycle → grade_level`

Isto permite manter o Ensino Secundário rigorosamente separado dos outros níveis e, ao mesmo tempo, reutilizar a mesma arquitetura para os restantes níveis.

## 2. Ciclo não é grupo/área

O ciclo responde a **onde o aluno está na estrutura do Ensino Secundário**.

A área, grupo, variante ou especialização responde a **qual organização curricular está a seguir**.

Portanto:

`2.º ciclo ≠ Grupo A/B/C`

O SIGE não vai codificar A/B/C como regra universal. O currículo oficial pode ser revisto e a disponibilidade de áreas varia por escola. Por isso criámos `academic_pathways`.

Exemplos de dados configuráveis:

- A — Comunicação e Ciências Sociais;
- B — Matemática e Ciências Naturais;
- C — outra área/especialização disponível;
- variantes específicas da escola.

A nomenclatura concreta é configuração curricular, não lógica de aplicação.

## 3. Turma

Uma turma é uma unidade operacional anual.

Exemplos:

- 7.ª A
- 7.ª B
- 8.ª A
- 8.ª B
- 10.ª A — área A
- 11.ª B — área B

A turma tem contexto:

- escola;
- ano letivo;
- classe;
- ciclo, derivado da classe;
- área/grupo, quando aplicável;
- turno;
- capacidade;
- código da secção;
- estado.

Não colocamos `student.class_id` como verdade académica. A pertença é temporal através de `class_placements`.

## 4. Grupo A/B/C e letra da turma são coisas diferentes

Isto é crítico.

`11.ª A` pode significar a **letra/identificador da turma**.

`Grupo B` pode significar uma **área curricular**.

Não podemos armazenar ambos como um único campo.

Exemplo:

| Classe | Grupo | Turma |
|---|---|---|
| 11.ª | A | A |
| 11.ª | A | B |
| 11.ª | B | A |
| 11.ª | B | B |

O SIGE deve conseguir distinguir:

- 11.ª A — Grupo A;
- 11.ª B — Grupo A;
- 11.ª A — Grupo B;
- 11.ª B — Grupo B.

## 5. Professor

A relação correta não é:

`Professor → Turma`

É:

`Professor → TeacherAssignment → CourseOffering → Turma + Disciplina + Ano`

Assim um professor pode lecionar:

- Matemática — 8.ª A;
- Matemática — 8.ª B;
- Matemática — 9.ª A;
- Física — 10.ª B.

Cada atribuição possui vigência própria.

Também é possível ter mais de um professor associado à mesma unidade de ensino quando a regra da escola exigir apoio/substituição.

## 6. Director de turma

Director de turma não é uma propriedade permanente do professor nem deve ser um campo textual da turma.

Usamos:

`class_group → class_group_leadership → teacher`

A relação possui:

- data inicial;
- data final;
- estado;
- motivo.

Isto preserva o histórico.

Exemplo:

- João foi director da 8.ª A de Janeiro a Junho;
- Maria assumiu em Junho.

O SIGE mantém ambas as relações.

## 7. O que a página de uma turma deve conseguir mostrar

Ao abrir uma turma, o utilizador autorizado deve encontrar uma visão consolidada.

### Identidade

- 8.ª A
- 2026/2027
- 1.º ciclo
- turno
- capacidade
- número de alunos
- área/grupo, quando existir
- director de turma

### Alunos

Lista com:

- número do aluno;
- nome;
- sexo;
- estado;
- fotografia, se existir;
- situação da matrícula;
- indicadores académicos relevantes.

Ao clicar no aluno:

- perfil;
- dados pessoais;
- encarregados;
- matrícula;
- colocação na turma;
- disciplinas;
- professores;
- notas/resultados;
- histórico;
- situação financeira, conforme permissão;
- transporte, conforme permissão;
- documentos, conforme permissão.

## 8. Professores da turma

A turma deve permitir visualizar:

| Disciplina | Professor | Estado |
|---|---|---|
| Matemática | ... | Ativo |
| Português | ... | Ativo |
| Física | ... | Ativo |

Isto deve vir de `course_offerings + teacher_assignments`, não de dados duplicados na turma.

## 9. Disciplinas da turma

Uma turma não deve simplesmente possuir uma lista manual de disciplinas.

A cadeia é:

`CurriculumSubject → CourseOffering → ClassGroup`

O currículo define o que pode/deve ser lecionado. A oferta anual concretiza isso para uma turma no ano letivo.

Isso permite que duas turmas da mesma classe tenham o mesmo currículo mas professores diferentes.

## 10. Horários

O horário deve ser construído sobre quatro recursos principais:

- turma;
- professor;
- sala;
- período.

Uma entrada de horário liga:

`Dia + Período + Turma + Disciplina + Professor + Sala`

O banco já possui exclusões temporais para impedir sobreposição de:

- turma;
- professor;
- sala.

A nova camada fornece projeções para:

- horário da turma;
- horário do professor;
- horário do aluno;
- utilização dos períodos;
- carga docente.

## 11. Distribuição de horários

O SIGE não deve obrigar a secretaria a preencher uma grelha cegamente.

O fluxo pretendido é:

1. configurar períodos;
2. configurar dias letivos;
3. abrir turmas;
4. abrir ofertas de disciplinas;
5. atribuir professores;
6. definir carga/necessidades;
7. distribuir as aulas;
8. o sistema verificar conflitos imediatamente;
9. publicar o horário.

A interface poderá mostrar slots livres/ocupados e conflitos antes da gravação.

### Restrições duras

Nunca permitir:

- professor em duas turmas no mesmo período;
- turma em duas disciplinas no mesmo período;
- sala ocupada por duas aulas no mesmo período;
- atribuição de professor incompatível com a oferta;
- horário fora da vigência da atribuição;
- turma/ano incompatíveis.

### Preferências

Estas não devem bloquear a operação automaticamente:

- professor prefere manhã;
- professor prefere determinados dias;
- distribuição equilibrada da carga;
- evitar demasiados tempos consecutivos;
- evitar janelas excessivas;
- distribuir uma disciplina ao longo da semana;
- respeitar necessidades de salas especiais.

Isto prepara o SIGE para um futuro **motor de geração/otimização de horários**, sem colocar um algoritmo frágil dentro da primeira versão.

## 12. Referência de modelação

O modelo segue um princípio semelhante ao utilizado em SIS maduros como Ed-Fi:

`Course → CourseOffering → Section`

com associações separadas para:

`Teacher → Section`

e

`Student → Section`.

Essa separação permite que uma oferta tenha várias secções, que um professor tenha várias atribuições e que um aluno possa mudar de secção preservando o histórico. citeturn0search0turn0search3

Para horários, o conceito de período também deve ser independente da turma. Um calendário pode ter diferentes horários/bell schedules e períodos, inclusive variações por dias ou grupos. citeturn4search1turn4search0

## 13. Decisão de engenharia

Não vamos criar uma tabela gigante chamada `turmas` contendo:

- professor;
- alunos;
- disciplinas;
- grupo;
- horário;
- director;
- notas.

Isso produziria duplicação e destruiria histórico.

O SIGE usa entidades pequenas e relações explícitas.

A turma é o agregado operacional para navegação, mas não é o dono de todos os dados relacionados.

## 14. Projeções preparadas

Foram adicionadas ao banco:

- `class_group_overview`
- `class_group_students`
- `class_group_teachers`
- `teacher_workload_summary`
- `class_timetable`
- `teacher_timetable`
- `student_timetable`
- `timetable_slot_usage`

Estas são **projeções de leitura**. Não são fontes de verdade.

## 15. Próxima camada

Com esta fundação, a UI poderá construir:

`Ensino Secundário → 1.º/2.º ciclo → Classe → Grupo/Área → Turmas → Turma`

e, dentro da turma:

`Resumo → Alunos → Professores → Disciplinas → Horário → Avaliação → Histórico`

A autorização continuará a determinar o que cada perfil pode visualizar ou alterar.

### Referências principais

- Plano Curricular do Ensino Secundário — Ministério da Educação de Moçambique. citeturn0search37
- Direcção Nacional do Ensino Secundário — Ministério da Educação e Cultura. citeturn0search5
- Ed-Fi Teaching and Learning Domain — Course, CourseOffering, Section, StaffSectionAssociation e StudentSectionAssociation. citeturn0search0turn0search3
- Ed-Fi Bell Schedule Domain — períodos, horários e variações de calendário. citeturn4search1turn4search7
