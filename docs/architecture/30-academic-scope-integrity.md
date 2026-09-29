# 30 — Integridade de escopo acadêmico

## Por que isto é necessário

Uma FK como `course_offering.class_group_id → class_groups.id` prova apenas que a turma existe. Não prova que a turma pertence à mesma escola, ao mesmo ano letivo ou ao mesmo contexto da oferta.

Em um sistema multi-escola, essa diferença é uma fronteira de segurança e integridade.

## Contextos protegidos

O PostgreSQL agora valida relações entre:

- escola ↔ ano letivo;
- escola ↔ currículo;
- escola ↔ turma;
- turma ↔ oferta;
- oferta ↔ currículo;
- aluno ↔ matrícula;
- matrícula ↔ turma;
- aluno ↔ disciplina;
- professor ↔ oferta;
- período ↔ ano;
- avaliação ↔ oferta/período;
- resultado ↔ aluno/oferta;
- horário ↔ escola/ano/turma/oferta/professor/sala/período;
- sessão de aula ↔ horário/oferta/professor;
- livro de ponto ↔ aluno/disciplina/sessão.

## Regra

Não basta existir uma relação. A relação deve pertencer ao mesmo contexto acadêmico.

Essa validação fica no banco porque qualquer proteção apenas no frontend poderia ser contornada por uma função privilegiada, uma importação ou uma operação administrativa futura.

## Próxima camada

Depois desta fundação, devemos auditar as mesmas propriedades no domínio financeiro e de serviços: aluno, escola, ano letivo, plano de cobrança, obrigação, pagamento, alocação, transporte e reversão.