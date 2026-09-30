# Pautas oficiais 12.ª Classe — modelos 12A/12B

## Fonte operacional

Foram analisados os modelos reais recebidos da escola: 12.ª Classe — Opção A e 12.ª Classe — Opção B.

Os modelos têm pauta principal, campos de exame, médias, resultado final, legenda, assinatura do Conselho de Exame e mapa de aproveitamento pedagógico.

## Regra de produto

A pauta no SIGE é editável enquanto o lançamento do exame estiver aberto.
- nota de exame: editável pelo fluxo de avaliação existente;
- frequência: resultado calculado, não digitado manualmente;
- média/final: derivados pelo motor normativo;
- resultados publicados: correcção auditada, sem UPDATE directo;
- impressão: reproduz a estrutura documental da escola;
- impressão: parte dos dados do SIGE, sem recalcular regras no browser.

## Mapeamento

Identificação: República de Moçambique, Província, Direcção Provincial da Educação, Escola, 12.ª Classe, Opção A/B, Pauta de Exame, Ano lectivo e Turma.

Linha do aluno: Nº de ordem, Código do aluno, Nome, Género, Turma, disciplinas, Frequência, 1.ª/2.ª chamada, Média, Média global e Resultado final.

Opção A: POR, ING, FIL, MAT, FRA, HIS, GEO, TIC, NE, EF, COMP.
Opção B: POR, ING, FIL, MAT, BIO, QUI, FIS, TIC, AGP, EF, COMP.

A ordem documental deve ser preservada na impressão.

## Domínio SIGE

A pauta não cria uma segunda fonte de verdade.
- assessment_results: lançamento do exame;
- academic_results: frequência/final calculados;
- grade_rule_versions: regra normativa vinculada ao ano lectivo;
- exam_sessions / exam_registrations: contexto de exame;
- academic_result_pauta: resultados académicos publicados.

O Excel original contém centenas de fórmulas auxiliares. Essas fórmulas são referência de comportamento, não devem ser copiadas para React.

## Impressão

Primeira superfície: impressão directa, guardar como PDF pelo diálogo de impressão, orientação horizontal, formato A3, cabeçalho institucional, pauta principal, mapa de aproveitamento e assinatura.

Excel nativo permanece como sub-bloco documental separado.

## Estado actual

O backend já possui save_assessment_result, correct_published_result, calculate_frequency_result, calculate_final_result, regras normativas versionadas, assessment_gradebook e academic_result_pauta.

A antiga página /pautas era somente leitura. Esta implementação começa a substituí-la por uma pauta operacional editável sem alterar o domínio já existente.

## Bloqueio de arquitectura

O histórico de migrations do GitHub e o histórico remoto do Supabase estão divergentes. Esta primeira camada usa os commands/views existentes e não introduz nova migration até a reconciliação.