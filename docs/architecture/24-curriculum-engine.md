# 24 — Motor curricular

## 1. Princípio

O currículo do SIGE não é uma lista hard-coded no frontend.

É uma configuração académica contextual:

**Ano letivo + Classe + Área/Pathway + Disciplina + Regra de escolha + Carga semanal**

O MEC mantém o Plano Curricular do Ensino Secundário Geral como documento oficial de referência. citeturn0search0

## 2. Hierarquia

**Ensino → Ciclo → Classe → Pathway/Área → Currículo → Oferta**

Área curricular, pathway e escolha individual não são a mesma coisa.

### Área curricular

É uma organização pedagógica do currículo. Exemplos: Comunicação e Ciências Sociais; Matemática e Ciências Naturais; Actividades Práticas e Tecnológicas.

### Pathway

É uma configuração de percurso/área que pode distinguir o conjunto curricular de uma turma. O SIGE não fixa A, B ou C no código.

### Escolha

É uma regra que permite ao aluno ou à organização seleccionar entre disciplinas. O plano curricular de 2022 apresenta componentes de tronco comum, áreas específicas e disciplinas opcionais no 2.º ciclo. citeturn2search0turn2search6

## 3. Disciplinas curriculares

`curriculum_subjects` representa uma disciplina dentro do currículo de uma classe.

A combinação principal é **ano + classe + disciplina + pathway**.

Assim podemos ter Matemática comum, Matemática específica de determinado pathway, Geografia comum ou Geografia opcional, sem duplicar a entidade `subjects`.

## 4. Modos de participação curricular

### REQUIRED
Todos os alunos daquela configuração curricular devem frequentá-la.

### OPTIONAL
A disciplina está disponível, mas não é obrigatória.

### CHOICE
A disciplina pertence a um grupo de escolhas. Exemplo: grupo de escolha X com Francês, Língua Moçambicana e Artes Cénicas, com mínimo 1 e máximo 1.

O motor não precisa saber que esse grupo é A/B/C. Ele conhece apenas a regra.

## 5. Carga semanal

`weekly_periods` representa o número de períodos semanais previstos para a disciplina.

Não transformamos isso em minutos automaticamente. A duração de um período pertence ao motor de horários.

Portanto: **Currículo → períodos/semana** e **Horário → duração do período** são responsabilidades distintas.

## 6. Versão por ano letivo

O currículo é associado a `academic_year_id`. Isto impede que uma alteração futura sobrescreva silenciosamente o currículo histórico.

Exemplo: 2026/2027, 8.ª, Matemática, 5 períodos; 2027/2028, 8.ª, Matemática, 4 períodos. São configurações diferentes.

## 7. Geração de ofertas

`CurriculumSubject → CourseOffering` para cada turma compatível.

A secretaria não deve cadastrar manualmente as disciplinas de cada turma. A operação `generate_class_offerings()` deriva as ofertas da configuração curricular.

## 8. Regra de prioridade

Quando existe uma disciplina comum e uma específica do pathway, a configuração específica daquele pathway tem prioridade, evitando duas ofertas da mesma disciplina na mesma turma.

## 9. O que não será hard-coded

Não colocaremos listas de disciplinas ou cargas horárias em condicionais TypeScript/SQL como regra estrutural. Essas informações pertencem aos dados curriculares.

## 10. Relação com avaliação

O currículo não calcula notas. Ele determina que uma disciplina existe e pertence ao percurso académico.

`CurriculumSubject → CourseOffering → Assessment → AssessmentResult → AcademicResult → Pauta`

A regra de avaliação permanece no motor académico.

## 11. Fonte normativa

O portal oficial do MEC disponibiliza o Plano Curricular do Ensino Secundário Geral entre os documentos curriculares oficiais. citeturn0search0

O documento de 2022 consultado descreve os dois ciclos e apresenta, no 2.º ciclo, tronco comum e áreas específicas com componentes opcionais. citeturn2search0turn2search6

Há materiais secundários que reproduzem versões anteriores do plano e nomenclaturas diferentes. Por isso o SIGE deve guardar a configuração curricular por ano, em vez de assumir que uma única grelha histórica é permanente. citeturn2search5turn2search21

## 12. Próxima camada

Com o motor curricular criado, faltam duas peças antes da UI académica definitiva:

1. seed/configuração curricular oficial inicial para 7.ª–12.ª, áreas, disciplinas, cargas semanais, opcionais e pathways aplicáveis;
2. motor de avaliação para períodos, ACS, AT, exame, média, resultado final, recuperação e regras versionadas.

A primeira peça deve ser carregada como dados de configuração, nunca como lógica do sistema.