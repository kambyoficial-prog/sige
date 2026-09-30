# Arquitetura de documentos académicos e impressão — SIGE

## Decisão

Os modelos Excel recebidos da Direção demonstram que a impressão não é detalhe de UI. É uma saída oficial do processo académico.

Arquitetura:

Domain / Ledger → Published Read Model → Document Projection → Browser Print / PDF / Excel.

A pauta é uma projeção; não recalcula nem altera resultados.

## 1. Três representações

### Dados académicos

Fonte de verdade: assessments, assessment_results, academic_results, exam_sessions, exam_registrations e cycle_outcomes.

### Read model documental

Estrutura preparada para impressão: instituição, ano, classe, opção, turma, template, disciplinas, alunos, resultados, legenda, homologação e assinaturas.

### Artefacto emitido

DocumentIssue identifica tipo, template, versão, fonte, data, emitente, snapshot e checksum.

## 2. Snapshot

Uma reimpressão futura não pode mudar porque o nome da disciplina, turma, cabeçalho, legenda ou outros dados correntes foram alterados.

Por isso o documento emitido congela o snapshot utilizado na emissão.

O snapshot não substitui os dados académicos; preserva a emissão documental.

## 3. Templates versionados

Não devemos criar um componente único com dezenas de condições para Grupo A, Grupo B e outras classes.

Preferir um perfil de template com código, versão, tipo documental, classe aplicável, opção aplicável e configuração de layout.

Exemplos iniciais: PAUTA_EXAME_12_A_2025 e PAUTA_EXAME_12_B_2025.

A versão 2025 deve continuar disponível mesmo quando existir uma versão 2026/2027.

## 4. Compatibilidade

Há duas compatibilidades diferentes.

Semântica: os dados têm o mesmo significado que no documento da escola.

Visual: o documento mantém organização, nomenclatura, ordem curricular, abreviações, homologação, assinatura, legenda e paginação que o Director reconhece.

Não devemos modernizar o documento oficial a ponto de ele deixar de ser reconhecível.

## 5. PDF

A primeira implementação pode ter uma rota de impressão dedicada, autenticada e autorizada, com CSS de impressão A4 landscape.

Essa rota deve carregar somente dados publicados ou um snapshot documental emitido, esconder a navegação e impedir elementos interativos no documento.

Para geração automatizada posterior, pode existir um renderer dedicado no backend. Next.js é adequado para a superfície web, enquanto uma função server-side dedicada pode tratar geração documental quando necessário. citeturn0search10turn0search7

## 6. Excel

Existem duas modalidades.

Exportação operacional: dados tabulares para análise e trabalho.

Reprodução do modelo escolar: template fornecido pela escola preenchido pelo SIGE.

A segunda modalidade deve ser versionada e testada como template, não utilizada como motor de cálculo.

## 7. Não duplicar regras

O renderer não deve decidir aprovação, calcular médias ou escolher época.

Ele recebe valores e estados já resolvidos pelo domínio.

Isso evita divergência entre tela, PDF e Excel.

## 8. Segurança

Só resultados elegíveis para publicação podem ser emitidos como pauta oficial.

CALCULATED e HOMOLOGATED podem existir como pré-visualização interna, mas não devem ser apresentados como documento oficial.

## 9. Reimpressão

Uma pauta publicada deve possuir identificador de emissão.

Reimprimir significa recuperar o mesmo snapshot. Não significa recalcular.

## 10. Correção

Quando uma pauta publicada contém erro:

1. corrigir o resultado através do command de correção;
2. homologar novamente;
3. publicar nova versão;
4. preservar a emissão anterior como substituída;
5. emitir nova pauta;
6. manter relação entre emissão anterior e nova emissão.

## 11. Testes documentais

Cada template deve ter testes de regressão.

Validar: quantidade e ordem das disciplinas, cabeçalho, grupo, número de alunos, notas, resultado, legenda, assinatura, homologação, paginação e ausência de conteúdo cortado.

Uma fixture sintética deve permitir comparar a saída gerada com o template recebido da escola.

## 12. Evolução

Receber um novo modelo da escola deve significar adicionar ou versionar um template, e não reescrever o domínio académico.

Essa separação é central para o SIGE.