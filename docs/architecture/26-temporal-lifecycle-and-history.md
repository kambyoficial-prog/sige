# 26 — Ciclo temporal, fecho e histórico académico

## Princípio

O SIGE não apaga anos lectivos nem substitui dados antigos por dados do novo ano.

O sistema trabalha com **contextos temporais**:

`Ano lectivo -> Trimestres -> Currículo/Ofertas -> Turmas -> Matrículas -> Avaliações -> Resultados`

Um novo ano cria um novo contexto. O anterior permanece consultável.

## Novo trimestre

Um trimestre não é uma nova base de dados nem uma cópia do sistema.

É um novo `assessment_period` dentro do mesmo ano lectivo:

- T1
- T2
- T3

Cada período tem estado:

- OPEN
- CLOSED

Enquanto OPEN, o fluxo normal permite lançamento/correção conforme as permissões.

Depois de CLOSED:

- novas avaliações desse período são bloqueadas;
- alteração de resultados é bloqueada;
- exclusões são bloqueadas;
- o histórico continua disponível;
- uma correção excepcional futura deverá usar command próprio, permissão própria, motivo e auditoria.

## Novo ano lectivo

Exemplo:

`2026/2027 -> CLOSED`

depois:

`2027/2028 -> DRAFT -> OPEN -> CLOSED`

O ano anterior não é duplicado nem apagado. O novo ano recebe os seus próprios:

- períodos;
- ofertas curriculares;
- turmas;
- professores;
- atribuições;
- matrículas;
- avaliações;
- resultados;
- cobranças.

Configurações reutilizáveis, como currículo e catálogo de disciplinas, podem ser reaproveitadas por referência/configuração, mas os registos operacionais continuam vinculados ao seu ano.

## Fecho

O fecho é uma operação administrativa, não apenas um botão visual.

Para fechar um trimestre:

1. avaliações devem estar fechadas/publicadas;
2. período é marcado CLOSED;
3. é gravado actor/data;
4. o período deixa de aceitar alterações normais.

Para fechar o ano:

1. não podem existir avaliações OPEN;
2. não podem existir períodos ativos OPEN;
3. não podem existir matrículas PENDING;
4. matrículas ativas são concluídas;
5. colocações temporais são encerradas;
6. ano passa a CLOSED;
7. operação é auditada.

## Imutabilidade

A proteção existe no banco de dados.

Triggers bloqueiam alterações normais em:

- assessments;
- assessment_results;
- academic_results

quando o ano está CLOSED.

A UI deve refletir esse estado, mas não é a responsável pela segurança.

## Histórico

A navegação deve ter um **context switch temporal**, por exemplo:

`Ano lectivo: 2026/2027`

Ao abrir:

- 2026/2027 — Fechado
- 2027/2028 — Aberto
- 2028/2029 — Rascunho

Ao selecionar 2026/2027, o sistema entra em modo histórico.

Nesse modo:

- leitura permitida;
- edição normal desativada;
- indicadores mostram que o contexto está fechado;
- pautas, turmas, alunos, professores, avaliações e resultados daquele ano continuam acessíveis.

Não se deve criar páginas duplicadas como `/historico/2026`.

O mesmo recurso deve funcionar por contexto:

`/turmas?academicYear=2026-2027`

ou através de um contexto global de navegação.

## Regra UX

O utilizador deve perceber claramente:

- qual ano está selecionado;
- se está OPEN ou CLOSED;
- qual trimestre está selecionado;
- se pode editar;
- quando um dado pertence a histórico.

Nunca esconder dados históricos só porque o ano fechou.

## Correções pós-fecho

Fecho não significa apagar nem tornar o histórico inacessível.

Também não significa permitir edição silenciosa.

Se uma nota oficialmente publicada precisar de correção após o fecho, deve existir um fluxo administrativo separado:

`Pedido de correção -> autorização -> nova versão -> motivo -> auditoria -> nova homologação/publicação`

O valor anterior permanece no ledger.

## Regra de engenharia

**Read historical, write current.**

A aplicação trabalha normalmente no contexto OPEN. Contextos CLOSED são predominantemente de leitura. Qualquer exceção é explícita, autorizada e auditada.
