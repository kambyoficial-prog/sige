# 42 — Pessoas, admissão e matrícula

## Objetivo

F3 estabelece o primeiro vertical slice operacional do SIGE para pessoas e matrícula.

A separação de domínio é deliberada:

1. Pessoa — identidade civil/institucional.
2. Aluno — relação permanente da pessoa com uma escola.
3. Matrícula — episódio anual do aluno.
4. Colocação — pertença temporal a uma turma.
5. Encarregado — pessoa responsável associada ao aluno.

Não existe uma operação genérica de CRUD que atravesse estas fronteiras.

## Registo de aluno

register_student cria, numa transação:

- people;
- students;
- número escolar;
- data de admissão;
- auditoria;
- resultado idempotente.

O comando valida:

- sessão autenticada;
- escola ativa;
- enrollment.manage;
- número escolar único na escola;
- documento nacional não duplicado;
- identidade mínima.

A matrícula anual não é criada automaticamente. Isto evita confundir admissão/identidade com a decisão académica de matrícula.

## Encarregados

create_guardian cria a pessoa, o registo de encarregado e a associação ao aluno numa única operação.

A associação suporta:

- relação;
- profissão;
- BI/documento;
- residência;
- telefone;
- encarregado principal;
- vive com o aluno.

## Matrícula

A matrícula continua a ser um episódio temporal.

O modelo permite:

- entrada inicial;
- transferência de entrada;
- reingresso;
- saída;
- novo episódio posterior no mesmo ano quando o estado temporal o permitir.

A colocação em turma continua separada e é validada no servidor contra:

- escola;
- ano letivo;
- classe;
- datas;
- estado da matrícula;
- estado da turma;
- capacidade;
- sobreposição temporal.

## Privacidade

A policy anterior de people permitia leitura global autenticada. F3 substitui-a por uma policy baseada em relações institucionais autorizadas.

Também foram adicionadas policies explícitas para:

- guardians;
- student_guardians;
- student_identifiers.

As projeções de leitura usam security_invoker.

## Superfícies canónicas

- /alunos — diretório.
- /alunos/novo — registo de identidade.
- /alunos/[id] — perfil contextual, read-oriented.
- /alunos/[id]/encarregados/novo — operação focada de associação.
- /matriculas — diretório de episódios.
- /matriculas/nova — matrícula anual.
- /matriculas/[id] — estado da matrícula e colocação.

Não existe um formulário monolítico "aluno + matrícula + turma".

## Pesquisa

Pesquisa de diretórios ocorre no servidor. A UI não descarrega toda a população para filtrar localmente.

## Normas consultadas

O Ministério da Educação e Cultura mantém o Plano Curricular do Ensino Secundário Geral na página oficial de documentos.

O regulamento geral de avaliação do ensino secundário está publicado pela Imprensa Nacional no Diploma Ministerial n.º 7/2019. A implementação não usa esse regulamento como substituto das decisões de domínio já versionadas no módulo académico.

## Gate F3

F3 é considerado implementado em código quando:

- identidade e matrícula têm comandos distintos;
- queries são server-side;
- RLS não expõe pessoas globalmente;
- mutações usam idempotência/auditoria;
- CTAs de escrita respeitam enrollment.manage;
- nenhuma password ou credencial de aluno é inventada a partir de data de nascimento.

Runtime continua dependente de uma instância PostgreSQL/Supabase autorizada do SIGE.
