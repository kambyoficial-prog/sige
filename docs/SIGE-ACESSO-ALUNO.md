# SIGE — Acesso autenticável do aluno

## Princípio

O aluno não precisa de um e-mail institucional para utilizar o portal.

O modelo separa:

**número escolar → identidade Auth técnica → conta SIGE → papel STUDENT → primeiro acesso → acesso activo**

O número escolar é o identificador que o aluno conhece. Não é armazenado como palavra-passe.

## Identidade técnica

O Supabase Auth exige uma identidade de autenticação compatível com os métodos configurados. Para alunos sem e-mail, o SIGE cria uma identidade técnica interna, não contactável, exclusivamente para autenticação.

Essa identidade:
- não representa um e-mail da escola;
- não é apresentada como contacto do aluno;
- não é usada para comunicação;
- não participa na autorização;
- fica ligada ao registo de pessoa através de `app_accounts`.

A autorização continua em:
- `app_accounts`;
- `account_roles`;
- permissões;
- RLS;
- relações académicas do aluno.

## Activação

A activação é uma operação administrativa protegida por `student.access.manage`.

A Direção e a Secretaria podem:
1. seleccionar um aluno ACTIVE;
2. activar o acesso;
3. o SIGE cria a identidade Auth técnica;
4. gera uma palavra-passe temporária aleatória;
5. cria `app_accounts`;
6. atribui `STUDENT` em `account_roles`;
7. marca `first_access_required = true`;
8. apresenta a credencial temporária uma única vez na interface.

Se qualquer etapa posterior falhar, a operação tenta remover a conta SIGE e o utilizador Auth já criado.

## Primeiro acesso

O aluno entra com:
- **código:** `school_number`;
- **palavra-passe:** credencial temporária entregue pela escola.

Após autenticação:
1. o SIGE detecta `first_access_required`;
2. impede a entrada normal no portal;
3. exige definição de uma nova palavra-passe;
4. actualiza a credencial no Supabase Auth;
5. marca `first_access_required = false`;
6. preenche `activated_at`;
7. libera o acesso normal.

A palavra-passe temporária não é guardada pelo SIGE.

## Recuperação

A recuperação de acesso deve continuar a ser tratada como operação administrativa própria. O número escolar identifica o aluno, mas não substitui uma prova de posse da conta.

Para alunos sem contacto digital verificável, a Secretaria continua a ser o ponto de recuperação.

## Limites

Não se deve:
- usar data de nascimento como palavra-passe permanente;
- transformar `school_number` em segredo;
- criar e-mails institucionais fictícios;
- colocar o papel STUDENT em `user_metadata`;
- dar ao aluno acesso escolar global apenas porque possui uma conta;
- expor a identidade técnica interna na UI.

## Estado actual

O ciclo de autenticação do aluno está fechado no nível de domínio:

**Aluno → activação → credencial temporária → primeiro acesso → palavra-passe pessoal → acesso autenticado**

A próxima camada é validar o comportamento com uma conta DEMO real e executar a matriz de autorização do perfil `STUDENT` sobre matrícula, turma, disciplinas, horário, notas e dados pessoais.