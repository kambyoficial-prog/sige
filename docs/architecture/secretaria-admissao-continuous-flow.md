# Secretaria — fluxo contínuo de admissão

## Decisão

O SIGE passa a tratar **Novo aluno** como um processo operacional contínuo, e não como um cadastro isolado seguido de navegação manual entre módulos.

A secretaria deve concluir, numa única jornada:

1. Dados essenciais do aluno.
2. Filiação / encarregado.
3. Matrícula anual.
4. Colocação na turma, quando existir uma turma compatível.

Os detalhes de backend, IDs, comandos, RPCs e separação entre entidades permanecem invisíveis para a secretaria.

## O que estava errado na experiência anterior

O sistema separava:

- Alunos > Novo aluno
- Matrículas > Nova matrícula
- Inscrições

Embora a separação seja válida no domínio, obrigar a secretária a navegar entre estes módulos para executar uma admissão normal cria custo cognitivo e aumenta a probabilidade de registros incompletos.

A implementação anterior já redirecionava Novo aluno para /matriculas/nova, mas ainda deixava a matrícula como um segundo formulário.

## Modelo de UX adotado

### Processo normal

Novo aluno → verificação de identidade → Aluno → Filiação → Matrícula e turma → Concluído

Antes de criar `people/students`, o servidor faz uma pré-verificação determinística:

- documento + tipo, quando informado;
- nome completo + data de nascimento, quando ambos disponíveis.

Uma coincidência documental bloqueia a criação e encaminha a secretaria para o aluno existente. Uma coincidência por nome + data de nascimento abre uma revisão explícita; a secretaria pode rever os dados ou confirmar que se trata de uma pessoa diferente.

A verificação usa as read boundaries/RLS existentes e não cria uma nova tabela nem duplica a regra de unicidade do comando `register_student`.

A jornada apresenta somente decisões que dependem da secretária.

O sistema automatiza:

- atribuição do número escolar;
- sugestão do ano letivo aberto;
- filtragem das turmas pela classe;
- filtragem das turmas pelo grupo/área quando aplicável;
- criação da matrícula;
- colocação na turma;
- retorno ao perfil do aluno.

### Exceções

A separação dos módulos continua existindo para operações administrativas específicas:

- alteração de uma matrícula existente;
- transferência;
- correção cadastral;
- formação/gestão de turmas;
- manutenção de inscrições;
- operações financeiras;
- operações pedagógicas.

Isto preserva o domínio sem obrigar o fluxo normal a expor a estrutura interna.

## Evidência externa

### Infinite Campus

A documentação oficial descreve um Census Wizard que consolida a criação de pessoa, agregado familiar, endereço e relações, e o fluxo de novo aluno inclui posteriormente o enrollment. O produto também recomenda pesquisar pessoas existentes antes de criar novos registros para reduzir duplicações.

Fontes:
- https://kb.infinitecampus.com/help/-new-student-registration-workflow
- https://kb.infinitecampus.com/help/census-wizard
- https://kb.infinitecampus.com/help/census-new-personfamily-set-up-study-guide-template

### PowerSchool

A documentação oficial de PowerSchool combina o cadastro/enrollment do novo aluno com mecanismos de procura de potenciais duplicados e correspondência de familiares. O número do aluno também pode ser atribuído automaticamente pelo sistema.

Fonte:
- https://ps.powerschool-docs.com/pssis-admin/25.1/enroll-students

## Decisões de produto

### Não fazer

- Não mostrar RPCs, IDs ou estados técnicos.
- Não obrigar a secretária a abrir três módulos para uma admissão normal.
- Não pedir transporte como requisito. Transporte é opcional.
- Não transformar o processo num formulário gigante com dezenas de campos.
- Não remover os módulos administrativos existentes só porque o fluxo normal foi simplificado.
- Não duplicar regras de negócio no frontend.

### Fazer

- Progressive disclosure.
- Defaults seguros.
- Campos obrigatórios mínimos.
- Continuidade de contexto.
- Recuperação de processos parcialmente concluídos.
- Erros em linguagem operacional.
- Ações idempotentes.
- Auditoria no backend.
- Perfil do aluno como ponto de continuidade depois da admissão.

## Próxima camada

A próxima evolução deve adicionar:

1. reaproveitamento de pessoa/encarregado já existente;
3. estado de processo pendente para admissões interrompidas;
4. geração/entrega de acesso do aluno quando o domínio de contas estiver pronto;
5. transporte como etapa opcional pós-admissão, sem bloquear o processo;
6. uma área de Pendências da secretaria que mostre apenas o que precisa de intervenção humana.

A regra permanece: **complexidade no domínio; simplicidade na operação.**
