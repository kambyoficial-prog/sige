# Reconciliação normativa — pauta escolar 2025 vs regra atualmente configurada no SIGE

## Achado

Os modelos reais enviados pela Direção são de 2025 e representam 12.ª classe. O modelo utiliza a fórmula de 12.ª com paralelismo: (2 × NCD + NE) / 3 e apresenta a lógica de exame em 1.ª/2.ª chamada.

Na base atual do SIGE existem duas versões de regra académica marcadas como ativas:

- MZ-ESG-RGA-2019
- MZ-ES-2022-06-30

O ano lectivo 2026/2027 do ambiente atual está associado à regra MZ-ES-2022-06-30.

## Por que isto não deve ser alterado agora

Não devemos trocar a regra ativa apenas para fazer o modelo Excel parecer correto.

Também não devemos concluir, a partir do Excel de 2025, que a regra normativa de 2026/2027 é idêntica.

O documento escolar é evidência operacional. A configuração normativa é uma decisão de aplicação para um determinado ano.

## O que deve ser confirmado pela Direção

1. Qual regulamento/regra está a ser aplicado em 2026/2027?
2. O modelo de pauta de 2025 continua válido sem alterações?
3. A 12.ª classe continua a usar (2 × NCD + NE) / 3?
4. NCD corresponde exatamente à média final da frequência?
5. O exame positivo continua com mínimo 9?
6. O resultado final positivo continua com mínimo 10?
7. A 2.ª chamada substitui a 1.ª quando é realizada?
8. CCS, MCN e APT continuam válidos e qual é o significado oficial de cada um?
9. A designação oficial continua sendo Opção A/Opção B?

## Regra de engenharia

Até esta confirmação, nenhuma destas regras deve ser promovida para hard-coded behavior específico de 2026/2027.

O motor continuará a usar GradeRuleVersion. A Direção fornecerá a regra aplicável e o SIGE fará o binding do ano à versão correta.

## Critério de fechamento

Consideraremos a regra de 2026/2027 congelada somente quando houver evidência documental ou confirmação formal da escola suficiente para identificar fórmula, limiares, épocas, estados especiais e critérios de aprovação.