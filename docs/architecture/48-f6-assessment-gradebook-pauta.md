# F6 — Motor de avaliação, gradebook e pautas

## Objetivo

Fechar avaliação académica como domínio transaccional e versionado, sem duplicar fórmulas na UI e sem transformar a pauta em fonte de verdade.

## Fonte normativa

Para o Ensino Secundário Geral, o SIGE usa como regra actualmente vinculada a novos anos o Diploma Ministerial n.º 7/2019, de 10 de Janeiro.

O regulamento estabelece para ESG o mínimo de três avaliações escritas por trimestre, 2 ACS e 1 AT; define MACS como média das ACS, MT como (2×MACS+AT)/3 e MFD como média das três médias trimestrais.

O mesmo regulamento identifica 10.ª e 12.ª classes como classes terminais de exame.

## Modelo

AcademicYear → GradeRuleVersion

CourseOffering + AssessmentPeriod → AssessmentDefinition

AssessmentDefinition → Assessment → AssessmentResult

AssessmentResult → AcademicResult

AcademicResult → Homologated → Published

Published AcademicResult → Pauta

## Regra congelada por ano

`academic_years.grade_rule_version_id` impede que um novo regulamento reescreva silenciosamente resultados históricos.

Cada `academic_result` também persiste `rule_version` e `input_snapshot`.

## AssessmentDefinition

A definição é um slot configurável de avaliação. Permite à escola ter, por exemplo, quatro ACS sem alterar schema nem criar `acs4`.

Campos relevantes:

- tipo;
- ordinal;
- obrigatório;
- conta na MACS;
- escala máxima;
- peso opcional;
- versão normativa.

O motor normativo do ESG 2019 usa ACS e AT para o cálculo trimestral. A estrutura suporta ACP, RECOVERY e outros eventos sem os misturar automaticamente no cálculo.

## Gradebook

`assessment_gradebook` é um read model para o lançamento. Ele combina avaliação, aluno, turma, disciplina e resultado corrente.

O professor altera `AssessmentResult` através do command boundary; não existe INSERT/UPDATE directo do Data API.

## Cálculo trimestral

O motor:

1. resolve o ano da oferta;
2. resolve a versão normativa ligada ao ano;
3. verifica participação do aluno;
4. considera apenas resultados publicados e válidos para cálculo;
5. exige o mínimo normativo de ACS;
6. exige a AT prevista;
7. calcula MT;
8. grava snapshot completo;
9. cria nova versão do resultado se necessário.

Valor matemático e valor apresentado são campos distintos. O arredondamento de apresentação não destrói a precisão do cálculo.

## MFD

Os três resultados trimestrais precisam ser publicados, pertencer ao mesmo aluno/oferta/ano e representar exactamente T1, T2 e T3.

## Exame

Exame é um tipo distinto de avaliação. A implementação não confunde exame com ACS nem permite que uma nota de exame seja lançada como avaliação contínua.

Para o ESG, as classes terminais verificadas são 10.ª e 12.ª.

## Pauta

`academic_result_pauta` só expõe resultados `PUBLISHED`.

Consequentemente:

- pauta não altera nota;
- pauta não recalcula média;
- pauta não é fonte de verdade;
- correcções passam pelo ledger e pelos comandos de domínio.

## Recuperação

`RECOVERY` existe como evento de avaliação. A recuperação não substitui automaticamente um resultado oficial.

Uma fórmula universal de recuperação só deve ser adicionada quando a regra normativa aplicável estiver validada ou quando existir decisão formal da escola.

## Segurança

RLS permanece activo. Tabelas operacionais de avaliação não aceitam escrita directa por `authenticated`; os comandos `SECURITY DEFINER` mantêm autorização explícita, actor derivado de `auth.uid()`, `search_path` fixo, locks e auditoria.

Os avisos do Security Advisor sobre funções `SECURITY DEFINER` são conhecidos e correspondem ao command boundary intencional; não devem ser eliminados através de revogação que quebre a API transaccional.

## Testes

O repositório contém `0033_f6_normative_gradebook.sql` para assertions estruturais. A instância remota não tem pgTAP instalado; por isso a verificação remota equivalente foi executada directamente sobre catálogo PostgreSQL e definições das funções.

## Fecho de exames

O domínio de exames agora possui ciclo de vida próprio:

`ExamSession → ExamRegistration → Assessment(EXAM) → AssessmentResult → FinalResult`

Uma sessão possui ano lectivo, classe, época 1 ou 2, período de realização e estado DRAFT/OPEN/CLOSED/CANCELLED.

A inscrição do candidato regista explicitamente a decisão de elegibilidade. A decisão é auditada; o frontend não pode fabricar uma inscrição através de INSERT directo.

### Segunda época

A 2.ª época é um evento distinto. Quando existe um resultado de exame publicado da 2.ª época para o mesmo aluno/disciplina, um cálculo baseado na 1.ª época é rejeitado. Isto implementa a regra normativa segundo a qual a nota da 2.ª época anula a da 1.ª época. citeturn5view0

### Fórmulas terminais

Para a regra `MZ-ESG-RGA-2019`, a definição congelada contém coeficientes numéricos:

- 10.ª, com paralelismo: `(3 × NCD + NE) / 4`;
- 12.ª, com paralelismo: `(2 × NCD + NE) / 3`;
- sem paralelismo: `(NCD + NE) / 2`.

Essas fórmulas estão na versão da regra e são consumidas pelo motor. A UI não contém coeficientes normativos. citeturn6view0

### Admissão e aprovação

O regulamento separa admissão ao exame, nota do exame, nota final por disciplina e aprovação/conclusão do ciclo. A implementação não transforma esses quatro conceitos numa única nota.

Para 10.ª e 12.ª, o motor de resultado do ciclo verifica os limiares normativos armazenados na versão da regra. A determinação detalhada de disciplinas de exame continua dependente da estrutura curricular configurada para a escola.

### Recurso de exame

Foi criado `exam_reviews` com workflow `REQUESTED → UNDER_REVIEW → DECIDED`.

A decisão mantém motivo, decisão, nota revista quando aplicável, relatório, decisor e timestamps. Uma revisão não sobrescreve silenciosamente o resultado histórico.

## Estado de release F6

F6 inclui agora:

- regra normativa versionada;
- definições configuráveis;
- gradebook;
- lançamento de avaliações;
- publicação;
- cálculo trimestral;
- MFD;
- exame;
- épocas 1/2;
- elegibilidade explícita;
- resultado final;
- aprovação/conclusão de ciclo;
- recurso/revisão;
- homologação/publicação;
- pauta derivada;
- auditoria;
- RLS e command boundary;
- testes estruturais.

F6 só será marcado como release-ready depois de o CI do repositório concluir lint, typecheck, testes e build.