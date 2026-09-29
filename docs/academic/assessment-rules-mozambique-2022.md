# Regras académicas — Ensino Secundário de Moçambique

## Fonte normativa

A implementação do motor de resultados do SIGE usa como referência normativa o Regulamento de Avaliação do Ensino Secundário, aprovado em 2022 pelo Ministério da Educação e Desenvolvimento Humano.

A regra não é tratada como uma coleção de colunas fixas. O SIGE separa avaliação (evento), resultado do aluno, período de avaliação, regra de cálculo, resultado académico derivado e publicação/homologação.

## Regras confirmadas

### Tipos

O regulamento de 2022 identifica Avaliação Contínua e Sistemática (ACS), Avaliação Trimestral (AT) e Exame.

O número mínimo de avaliações escritas por trimestre é 3: duas ACS e uma AT. O sistema, entretanto, aceita mais avaliações do que o mínimo regulamentar, sem criar colunas físicas acs1, acs2, acs3 etc.

### MACS

MACS = soma(ACS) / número de ACS.

O regulamento também reconhece avaliações práticas dentro da ACS. O domínio deve permitir vários eventos ACS sem confundir o instrumento pedagógico com uma coluna fixa.

### Média Trimestral

MT = (2 × MACS + AT) / 3

### Média de Frequência por Disciplina

MFD = (MT1 + MT2 + MT3) / 3

### Nota por Disciplina / Nota do Ciclo

A nota por disciplina é derivada da média de frequência por disciplina da última classe do ciclo; para disciplinas que terminam antes, usa-se a MFD da última classe em que a disciplina é lecionada.

### Nota Final com exame

Nas escolas abrangidas pela regra de paralelismo pedagógico:

NF = (2 × ND + NE) / 3

onde ND é a Nota por Disciplina e NE é a Nota do Exame.

### Escala

A classificação quantitativa é de 0 a 20 valores:

| Valores | Classificação |
|---:|---|
| 19–20 | Excelente |
| 17–18 | Muito Bom |
| 14–16 | Bom |
| 10–13 | Suficiente |
| 0–9 | Não Suficiente |

As classificações trimestrais, anuais e finais são apresentadas arredondadas às unidades.

## Consequências para o SIGE

### Não criar colunas ACS fixas

Errado: acs1, acs2, acs3, acs4.

Correto: AssessmentPeriod → Assessment → AssessmentResult.

Cada ACS é um evento independente.

### Mínimo regulamentar ≠ limite estrutural

O motor permite 2 ACS + 1 AT, 3 ACS + 1 AT, 4 ACS + 1 AT ou mais avaliações quando a escola precisar.

A regra de publicação verifica o mínimo regulamentar; o modelo de dados não impõe o mínimo através do número de colunas.

### Rascunho ≠ resultado publicado

Durante o lançamento, resultados podem estar incompletos e médias derivadas podem permanecer nulas. Na publicação, o conjunto elegível precisa estar completo; o resultado fica congelado; uma correção posterior exige comando próprio, motivo e auditoria.

### Exame

Exame não é apenas mais uma ACS. É um evento académico distinto, com ciclo próprio e participação própria.

### Recuperação

O SIGE deve suportar recuperação/recurso como evento/contexto de avaliação, mas não deve inventar uma fórmula de substituição ou ponderação.

Enquanto a regra normativa específica aplicável à escola não estiver confirmada, uma recuperação deve ser armazenada com tipo, data, resultado, contexto, motivo, relação com o resultado anterior e versão da regra aplicável.

A fórmula de recuperação será adicionada somente depois de validada em fonte normativa ou decisão formal da escola.

## Regra de implementação

Cada cálculo publicado deve guardar ou referenciar a versão normativa que o produziu.

Para 2022: MZ-ES-2022-06-30.

Isso permite que uma alteração normativa futura não reescreva silenciosamente pautas históricas.
