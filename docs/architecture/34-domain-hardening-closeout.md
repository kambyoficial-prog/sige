# 34 — Encerramento do bloco de domínio e integridade

## Estado

Este bloco consolida o hardening do núcleo académico, financeiro e operacional do SIGE.

## Fechado

### Académico

- ano letivo temporal e versionado;
- no máximo um ano OPEN por escola;
- anos CLOSED permanecem consultáveis;
- barreira de escrita no PostgreSQL para dados operacionais de anos fechados;
- matrícula -> colocação -> participação em disciplina;
- disciplina/oferta -> atribuição docente;
- contexto escola/ano validado por triggers;
- currículo contextual por ano/ciclo/classe/percurso;
- turmas com percurso configurável;
- director de turma;
- horários com conflitos de turma, sala e professor;
- conflito docente validado por identidade do professor, inclusive quando possui várias assignments.

### Avaliação

- ACS variável;
- mínimo de 2 ACS publicadas;
- 1 AT;
- MACS;
- MT;
- T1/T2/T3;
- MFD;
- resultado de frequência;
- exame em 9.ª e 12.ª;
- fórmula final dependente explicitamente do paralelismo pedagógico;
- homologação;
- publicação;
- correcção posterior auditada;
- snapshots dos dados de cálculo;
- versionamento da regra;
- resultados publicados não são sobrescritos silenciosamente.

### Financeiro

- cobrança vinculada ao ano letivo;
- serviços vinculados ao ano;
- validação escola/ano;
- alocações não podem ultrapassar pagamento;
- alocações não podem ultrapassar cobrança;
- pagamento confirmado/revertido;
- reversão transacional e auditada;
- recibo vinculado a pagamento confirmado;
- recibo único por pagamento;
- histórico financeiro preservado.

### Lifecycle

DRAFT -> OPEN -> CLOSED

O fecho:

1. valida avaliações;
2. valida períodos;
3. valida matrículas pendentes;
4. conclui matrículas;
5. encerra colocações;
6. encerra participações;
7. encerra assignments;
8. encerra horários;
9. fecha ofertas;
10. fecha turmas;
11. fecha o ano;
12. audita a operação.

Tudo ocorre dentro da mesma transação do comando.

## Recuperação

academic_result_type = RECOVERY existe no modelo.

A fórmula, elegibilidade e impacto sobre a nota final/transição permanecem deliberadamente não implementados. Não existe uma fórmula genérica criada por inferência.

Quando a regra normativa for confirmada, deverá ser adicionada como nova versão de regra, com testes próprios.

## Regra de engenharia

O frontend não é fonte de verdade para:

- autorização;
- contexto escolar;
- ano letivo;
- integridade de turma;
- integridade docente;
- cálculo oficial;
- publicação;
- fecho.

Essas garantias pertencem ao PostgreSQL e aos comandos transacionais.

## Testes adicionados neste bloco

- 0021_financial_lifecycle.sql
- 0022_closed_year_write_barrier.sql
- 0023_academic_lifecycle.sql
- 0024_academic_result_lifecycle.sql
- 0025_timetable_assessment_integration.sql

## Limitação de validação

As migrations e testes foram revisados estruturalmente no repositório, mas ainda não foram executados contra uma instância PostgreSQL/Supabase autorizada para o SIGE.

O projeto Supabase atualmente conectado pertence a outro sistema e não deve ser usado para esta validação.

Portanto, o estado correto é:

SQL projetado e revisado; execução PostgreSQL pendente.

Não deve ser declarado migrations passed antes dessa execução.

## Próximo domínio

Com o núcleo fechado, o próximo passo de engenharia é o contrato da aplicação:

- TypeScript;
- tipos derivados do domínio;
- command/query contracts;
- cliente Supabase;
- tratamento de erros tipado;
- autorização no servidor;
- adapters/repositories;
- testes de integração;
- CI;
- depois UI.

A interface não deve duplicar regras já estabelecidas no banco.
