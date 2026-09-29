# SIGE — Fecho do bloco de fundação operacional

**Data:** 2026-09-29

## O que está fechado

### Enrollment
- episódios temporais de matrícula;
- reentrada no mesmo ano sem apagar histórico;
- matrícula separada de colocação;
- colocação com capacidade;
- conflito temporal no banco;
- autorização por escola;
- idempotência;
- auditoria.

### Finance
- record payment;
- confirm payment;
- allocate payment;
- cálculo de saldo sem duplicação por joins;
- descontos/waivers/surcharges considerados;
- allocation protegida por locks;
- mutations financeiras críticas fora do CRUD;
- histórico sem DELETE.

### Assessment
- create assessment;
- save result;
- teacher scope;
- publish;
- correction de resultado publicado;
- histórico de revisão;
- publicação só quando os participantes elegíveis têm resultado;
- mutações críticas fora do CRUD.

### Academic year
- DRAFT -> OPEN -> CLOSED;
- abertura command;
- fecho command;
- bloqueio de fecho com avaliações abertas;
- bloqueio de fecho com matrículas pendentes;
- encerramento dos episódios activos;
- auditoria.

### Security
- RLS;
- grants explícitos;
- funções privilegiadas com search_path fixado;
- funções do Data API default-deny;
- commands explicitamente concedidos a authenticated;
- anon sem execução;
- private command idempotency registry.

## O que continua deliberadamente fora

- fórmula oficial final das médias;
- valores reais de propinas;
- regras locais de recuperação;
- documentos obrigatórios de matrícula;
- credenciais iniciais de alunos;
- relatórios finais;
- UI operacional.

Esses pontos dependem de política escolar, regulamentação ou decisões de produto e não devem ser inventados pelo código.

## Referências externas verificadas

O modelo de episódios de matrícula segue a ideia de manter períodos de entrada/saída separados e permitir reentrada sem apagar histórico, em linha com as práticas de Enrollment do Ed-Fi. A separação entre calendário, enrollment e secções/ofertas também é coerente com a modelagem Ed-Fi atual.

A segurança combina grants e RLS, seguindo a recomendação atual do Supabase de tratar ambos como camadas distintas e de restringir explicitamente funções expostas pela Data API.
