# SIGE — Ciclo administrativo do aluno e cadastro docente

## Regra de domínio

O SIGE não trata matrícula, inscrição e propinas como a mesma operação.

### Matrícula
Estabelece o vínculo/matrícula anual do aluno com a escola e o respetivo contexto académico.

### Inscrição
É o ato administrativo de inscrever o aluno para frequentar o ano letivo. A inscrição referencia uma matrícula anual válida.

Tipos suportados: INITIAL, RENEWAL, TRANSFER_IN e REENTRY.

A renovação não cria outro aluno e não substitui o histórico anterior.

### Propinas / mensalidades
São obrigações financeiras independentes da matrícula e da inscrição.

O sistema suporta taxa/obrigação de inscrição, mensalidades por mês e vencimento, pagamentos, alocação de pagamentos, saldo, ajustes e transporte apenas quando o aluno adere ao serviço.

Os valores não são inventados pelo sistema: são configurados pela escola/gestão financeira.

## Professores

Professor é uma pessoa com vínculo docente à escola. O cadastro não exige e-mail institucional.

O cadastro usa código do professor, nome e apenas os dados pessoais/profissionais efetivamente fornecidos pela escola.

A atribuição pedagógica permanece separada: professor -> oferta disciplinar -> turma -> disciplina -> horário.

Uma conta de acesso docente, se necessária no futuro, é uma preocupação de autenticação separada do cadastro civil/profissional. Não se deve fabricar um e-mail institucional inexistente.

## Segurança

As mutações são command-oriented, auditadas e idempotentes. A nova entidade de inscrição possui RLS e a criação de professor valida teacher.manage no servidor.

## Limites

O SIGE não deve preencher automaticamente valores reais de propinas, documentos obrigatórios, salários, e-mails ou outras informações que a escola ainda não forneceu.
