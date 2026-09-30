# SIGE — Lifecycle de acesso por identidade

## Regra

Cadastrar uma pessoa no SIGE não cria automaticamente uma conta.

O ciclo é separado:

**Pessoa → vínculo escolar → papel → conta Auth → primeiro acesso → acesso ativo**

Isso evita que um professor cadastrado pela Secretaria ganhe privilégios antes de existir uma atribuição de acesso legítima.

## Professor

O cadastro do professor não exige e-mail institucional.

Quando a escola quiser ativar o acesso:

1. o professor deve existir e estar ACTIVE;
2. a operação exige teacher.manage;
3. é fornecido um endereço de e-mail real e alcançável;
4. o SIGE envia o convite Auth;
5. cria app_accounts;
6. atribui o papel TEACHER;
7. marca first_access_required = true.

O papel não é obtido de user_metadata. A autorização continua em app_accounts + account_roles + permissões/RLS.

## Secretaria

A criação de funcionário de Secretaria continua sendo uma operação única do ponto de vista do produto, mas possui uma fronteira externa: o convite do Supabase Auth.

O código implementa compensação se uma etapa posterior falhar:

- elimina a conta Auth criada;
- elimina app_accounts;
- elimina staff_members;
- elimina employments;
- elimina people.

Isso reduz o risco de registros órfãos.

## Aluno

O acesso do aluno não deve depender de um e-mail institucional inventado.

A conta do aluno será fechada separadamente com um identificador de acesso compatível com a realidade da escola. O school_number pode ser o identificador escolar, mas não deve ser tratado como senha.

Enquanto o mecanismo definitivo de autenticação do aluno não estiver fechado, não se deve criar contas Auth artificiais em massa.

## Primeiro acesso

Contas criadas por convite entram com:

- first_access_required = true;
- credential_issued_at preenchido;
- papel atribuído no banco;
- nenhuma autorização derivada de user_metadata.

O Supabase recomenda que ações administrativas de Auth sejam executadas somente em ambiente confiável com a chave secreta, nunca no browser. O SIGE mantém esse limite no server action/admin client.

## Segurança de sessão

A revogação de acesso e a duração dos tokens devem ser tratadas como parte do lifecycle, não apenas como logout visual. O Supabase utiliza access tokens JWT e refresh tokens; um token já emitido pode permanecer válido até sua expiração, salvo mecanismos adicionais de validação de sessão.

## Resultado

A arquitetura passa a distinguir claramente:

- cadastro — pessoa existe;
- vínculo — pessoa é professor/aluno/funcionário;
- papel — define capacidades;
- conta — identidade autenticável;
- primeiro acesso — ativação inicial;
- escopo — recursos efetivamente acessíveis.

Isso evita o erro clássico de transformar “tem conta” em “pode ver tudo”.
