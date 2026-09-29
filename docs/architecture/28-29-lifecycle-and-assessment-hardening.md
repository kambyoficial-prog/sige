# 28–29 — Hardening do lifecycle acadêmico e regime pedagógico

## Decisões fechadas

### Um único ano letivo aberto

Uma escola pode preparar anos em DRAFT, mas só pode possuir um ano OPEN por vez.

### Fecho do ano

O fechamento agora rejeita avaliações abertas, períodos de avaliação abertos, matrículas pendentes e colocações futuras incompatíveis com a data de fecho. Depois conclui matrículas ativas, encerra colocações e participações em disciplinas e fecha o ano.

### Cálculo da MFD

A frequência anual não aceita simplesmente três resultados quaisquer. Os três resultados devem representar exatamente T1, T2 e T3 do mesmo aluno, oferta, ano e contexto de resultado publicado.

### Regime pedagógico

O regulamento de avaliação do Ensino Secundário distingue a fórmula de Nota Final segundo a existência de paralelismo pedagógico. O SIGE passou a guardar essa configuração explicitamente na escola.

Com paralelismo: (2 × NCD + EXAM) / 3.
Sem paralelismo: (NCD + EXAM) / 2.

Se a configuração estiver ausente, o motor bloqueia o cálculo final.

## Próxima lacuna

O motor de resultados ainda não está concluído. Precisamos modelar separadamente elegibilidade para exame, critérios de aprovação, 2.ª chamada, conselho de exame, alteração formal de nota, recurso/revisão, recuperação e publicação de pauta.