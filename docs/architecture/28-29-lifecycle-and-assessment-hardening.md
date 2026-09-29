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

## Estado após F6

O motor base de avaliação está fechado como domínio transaccional:

- ano lectivo ligado a uma versão normativa congelada;
- definições de avaliação configuráveis por oferta/período;
- eventos ACS/ACP/AT/EXAM/RECOVERY sem colunas físicas fixas;
- lançamento e publicação de resultados de avaliação;
- cálculo de MT e MFD a partir de resultados publicados;
- ledger de resultados académicos com snapshot e versão normativa;
- homologação e publicação separadas;
- gradebook como read model operacional;
- pauta como read model exclusivamente derivado de resultados publicados.

### Limites deliberados

Elegibilidade detalhada de exame, 2.ª época, recurso/revisão e regras de recuperação continuam a ser eventos de domínio próprios. Não foram comprimidos numa fórmula genérica nem inferidos de regras não validadas.

A regra normativa actualmente vinculada a novos anos é `MZ-ESG-RGA-2019`. O identificador histórico `MZ-ES-2022-06-30` permanece apenas para compatibilidade com resultados já gravados.