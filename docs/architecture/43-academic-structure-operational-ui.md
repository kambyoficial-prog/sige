# 43 — Estrutura pedagógica e operação de turmas

## Objetivo

F4 transforma a estrutura académica já modelada no backend numa superfície operacional real.

Hierarquia:

nível de ensino → ciclo → classe → percurso/área → turma → oferta disciplinar → professor.

O sistema não transforma A/B/C em regra de negócio. Secção e percurso são dados configuráveis.

## Turmas

A criação de turma usa:

- ano letivo;
- classe;
- código de secção;
- nome apresentado;
- turno;
- capacidade.

A validação do servidor continua responsável por:

- contexto escola/ano;
- classe existente;
- compatibilidade do percurso;
- unicidade;
- estado do ano.

## Currículo → ofertas

A operação "Gerar disciplinas" chama generate_class_offerings.

A UI não copia manualmente disciplinas para cada turma. A oferta é derivada do currículo configurado.

Isto evita divergência entre currículo, disciplinas da turma, avaliação e pauta.

Se o currículo não estiver configurado, a interface informa a dependência em vez de criar dados fictícios.

## Professores

Uma oferta pode ter um professor temporalmente atribuído.

O modelo continua a permitir:

- um professor em várias turmas;
- várias ofertas;
- substituição temporal;
- verificação de contexto.

A atribuição usa assign_teacher_to_offering.

## Diretor de turma

A direção da turma usa assign_class_group_director.

O comando exige que o professor:

1. pertença à mesma escola;
2. esteja associado à turma através de uma oferta/atribuição docente;
3. tenha datas dentro do ano letivo;
4. passe pela autorização operations.manage.

A interface, portanto, lista para a operação de direção apenas docentes efetivamente ligados à turma.

## Segurança de leitura

As projeções class_group_directory e course_offering_directory são security_invoker.

A liderança de turma possui RLS explícito por escola.

## Superfícies canónicas

- /turmas — diretório.
- /turmas/nova — criação.
- /turmas/[id] — contexto operacional completo:
  - estado;
  - capacidade;
  - alunos;
  - disciplinas;
  - docentes;
  - diretor de turma.

Não existe uma segunda página duplicada apenas para "professores da turma".

## Decisão sobre horários

F4 não tenta resolver o problema de distribuição de horários. O backend já possui o domínio de horários e conflitos; a operação de horários permanece em F5.

## Base normativa

A página oficial do MEC disponibiliza o Plano Curricular do Ensino Secundário Geral. A arquitetura respeita a existência de 1.º e 2.º ciclos e mantém percursos/áreas configuráveis.

## Gate F4

F4 é considerado implementado em código quando:

- turmas usam comandos reais;
- ofertas são derivadas do currículo;
- professores são atribuídos por comando;
- direção de turma respeita a relação docente;
- capacidade e contexto permanecem no backend;
- leitura é feita por projeções autorizadas;
- não existem secções A/B/C hardcoded como regras.

Runtime e validação de constraints continuam dependentes da base SIGE autorizada.
