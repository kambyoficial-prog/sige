# Pauta 12.ª Classe — análise do modelo escolar real (2025)

## Objetivo

Este documento regista a análise dos dois modelos Excel fornecidos pela Direção: Pauta de Exame — 12.ª Classe — Opção A — 2025 e Pauta de Exame — 12.ª Classe — Opção B — 2025.

O objetivo é separar regras académicas reais, estrutura curricular, estados de resultado, fórmulas, homologação, estatísticas e requisitos de impressão do legado de implementação do Excel.

A pauta continua sendo um documento de saída. A fonte de verdade permanece no ledger académico e nos comandos de domínio.

## 1. Estrutura visual observada

Ambos os modelos são documentos de uma página, preparados para impressão em paisagem.

Cabeçalho: República de Moçambique; província; Direcção Provincial da Educação; escola; distrito; classe; opção; ano lectivo; pauta de exame; área de homologação pelo Director da Escola.

Corpo: número de ordem; código do aluno; nome do aluno; género; turma de proveniência; blocos de disciplinas; resultado final; assinatura do conselho de exame; legenda; observações; assinatura do presidente do conselho de exame.

A versão preenchida pelo SIGE deve conservar a identidade operacional do modelo e substituir os campos manuais por dados oficiais.

## 2. Estrutura curricular confirmada

### Opção A

Português, Inglês, Filosofia, Matemática, Francês, História, Geografia, TIC, Noções de Empreendedorismo e Educação Física.

### Opção B

Português, Inglês, Filosofia, Matemática, Biologia, Química, Física, TIC, Agropecuária e Educação Física.

Conclusão: Grupo/Opção é uma dimensão curricular real e não uma etiqueta visual.

O SIGE deve derivar as disciplinas da combinação ano lectivo + classe + currículo/opção. Não devemos manter listas fixas de disciplinas no frontend.

## 3. Estrutura de cada disciplina

Cada disciplina terminal apresenta Frequência, 1.ª/2.ª chamada e Média.

A pauta não é o gradebook. Ela apresenta o resultado terminal consolidado.

Modelo lógico: resultado de frequência + tentativa de exame válida → resultado final da disciplina.

1.ª e 2.ª chamadas devem continuar sendo eventos/sessões distintos no domínio; a expressão 1ª/2ª ch é apenas uma compactação documental.

## 4. Fórmula observada

Para a 12.ª classe com paralelismo pedagógico, as fórmulas da planilha implementam: NF = (2 × NCD + NE) / 3.

NCD é a nota/classificação de frequência utilizada pela pauta; NE é a nota do exame válida; NF é o resultado final.

A planilha arredonda o resultado apresentado para inteiro.

Esta fórmula não deve ser implementada em React, TypeScript ou Excel. Deve ser consumida por uma GradeRuleVersion e pelo motor de resultados.

O AcademicResult deve preservar valor matemático, valor apresentado, versão da regra e os inputs que originaram o resultado.

## 5. Segunda chamada

As fórmulas tratam 1.ª e 2.ª chamada como alternativas. Quando a primeira chamada é ausência e existe nota válida na segunda, a segunda pode ser utilizada. Estados como fraude, ausência e exclusão não devem ser convertidos em números.

O SIGE deve representar ExamSession epoch 1 e ExamSession epoch 2 e resolver a tentativa válida segundo uma regra versionada.

Não devemos armazenar 1ª/2ª ch como uma string de negócio.

## 6. Estados não numéricos observados

A legenda identifica: c) = Concluiu; d) = Não Faz a Disciplina; Exc = Excluído; A = Ausente; F = Fraude.

Isto prova que uma marca académica não é sempre um número.

O domínio deve separar valor numérico de estado de resultado. Estados conceptuais: NUMERIC, ABSENT, FRAUD, EXCLUDED, COMPLETED e NOT_TAKING.

A apresentação documental pode continuar usando exatamente A, F, Exc, c) e d) para compatibilidade com a escola.

## 7. Limiares observados

A planilha distingue pelo menos exame positivo a partir de 9 e resultado final positivo a partir de 10.

Esses valores não devem ser constantes globais. Pertencem à versão da regra académica aplicável ao ano, classe e regime.

## 8. Aprovação global

A planilha possui lógica para verificar disciplinas positivas e produzir Aprovado(a) ou Reprovado(a), além da média global.

Portanto, média global ≥ 10 não deve ser tratada isoladamente como regra universal de aprovação.

O motor deve separar resultado por disciplina, disciplinas positivas, estados especiais, média global, regras de admissão/conclusão e resultado final do ciclo.

## 9. Classificações especiais

A planilha contém códigos/resultados como CCS, MCN e APT e possui lógica para combiná-los em textos finais.

Os significados normativos não devem ser inferidos pelo SIGE. A escola deve confirmar nome completo, significado, condição, origem normativa, autoridade, impacto e forma de apresentação.

Até essa confirmação, esses códigos devem ser tratados como classificações normativas configuráveis, não como lógica hard-coded.

## 10. Estatísticas

A folha contém mapas de aproveitamento pedagógico e estatística.

Faixas observadas: 0–5.9; 6–8.9; 9–13.9; 14–16.9; 17–20.

As agregações incluem M, H e HM.

Também existem indicadores de previstos, avaliados, positivos e percentagem dos positivos, além de um mapa por escala com 0–9, 10–13 e 14–20 e separação entre 1.ª chamada, 2.ª chamada e total.

Conclusão: a pauta também é instrumento de consolidação estatística.

No SIGE essas estatísticas devem ser read models derivados dos resultados publicados, nunca valores digitados na pauta.

## 11. O que não deve ser copiado do Excel

O ficheiro contém centenas de colunas auxiliares, fórmulas intermediárias e referências posicionais.

Isso é implementação histórica, não domínio.

Não devemos reproduzir colunas ocultas, lógica duplicada, códigos espalhados em fórmulas, strings compostas para classificação ou dependência de posições de coluna.

O SIGE deve ter motor de resultados e camada de projeção documental.

## 12. Modelo académico alvo

AcademicYear → GradeLevel → Curriculum/Pathway → CurriculumSubject → CourseOffering → StudentParticipation → FrequencyAssessments → FrequencyResult → ExamRegistration → ExamSession 1/2 → ExamResult → SubjectFinalResult → CycleOutcome → Published Pauta.

## 13. Publicação

Fluxo: Avaliação → Resultado → Homologação → Publicação → Pauta.

A pauta publicada nunca altera nem recalcula resultados.

Uma correção cria nova versão do resultado, preserva a anterior e exige o fluxo de homologação/publicação definido pela escola.

## 14. Impressão é requisito de primeira classe

O SIGE deve permitir visualizar, imprimir, exportar PDF, exportar Excel e reimprimir.

O PDF deve preservar cabeçalho institucional, logótipo, opção/grupo, ano lectivo, turma, alunos, disciplinas, notas, resultados, legenda, homologação, assinaturas e observações.

O Excel deve existir tanto para exportação operacional quanto, quando solicitado, para reprodução do template escolar preenchido.

Uma pauta publicada deve poder ser reimpressa sem recalcular resultados.

## 15. Emissão documental

Separar AcademicResult de DocumentIssue.

DocumentIssue deve identificar documento, tipo, ano, escola, turma, opção/grupo, versão do resultado, emitente, data, template/version, snapshot e checksum.

Isso permite reimpressão, auditoria, comparação de versões e prova de qual documento foi homologado.

## 16. Templates versionados

Os templates devem ser perfis versionados, por exemplo PAUTA_EXAME_12_A_2025 e PAUTA_EXAME_12_B_2025.

O layout 2025 não deve ser destruído quando a escola mudar o modelo em 2026/2027.

Alterar documento deve significar trocar template, não alterar o domínio académico.

## 17. Questões abertas com a escola

1. O modelo de 2025 continua válido em 2026/2027?
2. Opção A/B é a designação oficial atual?
3. Existem outras opções?
4. Qual é o nome oficial de NCD?
5. A fórmula (2×NCD+NE)/3 aplica-se a todas as disciplinas?
6. O limiar de exame é realmente 9?
7. O limiar final é realmente 10?
8. Como funciona exatamente a 2.ª chamada?
9. O que significam CCS, MCN e APT?
10. Quando cada código é atribuído?
11. Como A, F, Exc, c) e d) impactam o resultado final?
12. Como é calculada a média global?
13. A média global participa na decisão de aprovação?
14. O mapa estatístico é parte da pauta oficial ou anexo de trabalho?
15. A escola necessita PDF e Excel, ou ambos?
16. Existem modelos para 10.ª/11.ª classe e 1.º ciclo?
17. Existe boletim/histórico/certificado com a mesma nomenclatura?

## 18. Critério de aceitação

O bloco só estará fechado quando um aluno anonimizado puder ser processado, o grupo curricular determinar corretamente as disciplinas, frequência e exame forem separados, 1.ª e 2.ª chamadas forem eventos distintos, estados não numéricos forem preservados, resultados forem reproduzíveis, aprovação for determinada por regra versionada, a pauta for somente leitura, e a pauta publicada puder ser reimpressa em PDF e Excel no modelo aprovado.

## Referência de arquitetura

A separação entre Gradebook, Report Card e Student Transcript é também uma prática documentada no modelo académico da Ed-Fi. O SIGE aplica o mesmo princípio adaptado às regras da escola. citeturn0search0turn0search4