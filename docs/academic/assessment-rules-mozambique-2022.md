# Regras académicas — Ensino Secundário Geral de Moçambique

## Fonte normativa validada

A regra normativa actualmente vinculada a novos anos lectivos no SIGE é o Diploma Ministerial n.º 7/2019, de 10 de Janeiro — Regulamento Geral de Avaliação do Ensino Primário, Alfabetização e Educação de Jovens e Adultos e Ensino Secundário Geral.

A Imprensa Nacional confirma que o diploma aprova o regulamento e revoga o Diploma Ministerial n.º 59/2015; entrou em vigor no ano lectivo de 2019. citeturn1search0

O catálogo da Imprensa Nacional também regista o Diploma Ministerial n.º 41/2022, mas este aprova o Plano de Estudo da 12.ª classe; não foi usado como fonte de fórmula de avaliação. citeturn5search4

## Regras ESG implementadas

### Avaliações trimestrais

O artigo 49 estabelece para o Ensino Secundário Geral um mínimo de três avaliações escritas por trimestre: 2 ACS e 1 AT. A classificação trimestral deve considerar os resultados de ACS e AT. citeturn3search0

O SIGE não transforma esse mínimo em colunas físicas. Pode haver 2, 3, 4 ou mais eventos ACS. O mínimo é uma regra de elegibilidade do cálculo, não um limite estrutural da base de dados.

### MACS

MACS é a média aritmética das ACS realizadas.

### Média Trimestral

MT = (2 × MACS + AT) / 3. citeturn3search0

### Média de Frequência por Disciplina

MFD = (MT1 + MT2 + MT3) / 3. citeturn3search0

### Escala

| Valores | Classificação |
|---:|---|
| 19–20 | Excelente |
| 17–18 | Muito Bom |
| 14–16 | Bom |
| 10–13 | Satisfatório |
| 0–9 | Não Satisfatório |

O SIGE guarda o valor matemático e a apresentação arredondada separadamente.

### Exames

O regulamento identifica as classes terminais de exame como 10.ª e 12.ª classes. O artigo 91 também descreve as disciplinas de exame e o regime de 1.ª/2.ª época. citeturn7search0

Por isso o SIGE não trata a 9.ª classe como classe terminal de exame.

### Critérios de transição/aprovação

O regulamento separa cálculo de médias de elegibilidade/aprovação. Os artigos 79 e 80 definem condições de transição do 1.º e 2.º ciclos; os artigos 96 e 97 tratam critérios de aprovação nas classes de exame. citeturn4search0

Essas regras não devem ser escondidas dentro da fórmula de uma nota disciplinar.

## Recuperação e 2.ª época

O SIGE suporta RECOVERY como tipo de avaliação/evento, mas não inventa uma fórmula universal de substituição da nota.

A 2.ª época de exame também permanece como evento distinto. O regulamento determina, entre outras regras, que a nota obtida na 2.ª época anula automaticamente a nota da 1.ª época. citeturn7search0

A implementação definitiva dessas transições exige um modelo específico de exame/época e não deve ser simulada através de simples alteração da nota final.

## Versionamento

Cada ano lectivo referencia explicitamente grade_rule_version_id.

Um resultado académico guarda o código da regra, snapshot dos inputs, valor matemático, valor apresentado, classificação, autor, timestamps e relação de supersessão quando há recálculo.

A regra actualmente criada para novos anos é MZ-ESG-RGA-2019.

O antigo identificador MZ-ES-2022-06-30 foi mantido apenas como compatibilidade histórica para resultados já gravados; não é usado como fundamento normativo para novos cálculos.

## Regra de engenharia

Nunca criar acs1/acs2/acs3/acs4, fórmulas hardcoded no frontend, uma segunda fonte de verdade na pauta, ou uma recuperação que simplesmente substitua uma nota sem evento e auditoria.

O fluxo permanece:

AssessmentDefinition → Assessment → AssessmentResult → AcademicResult → Homologation → Publication → Pauta.