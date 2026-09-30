# SIGE — Identidade, Contas e Primeiro Acesso

## Estado

Implementação de engenharia — Fase 1, Ensino Secundário.

## 1. Separação fundamental

O SIGE não confunde pessoa, vínculo institucional e autenticação.

```
Pessoa
  ↓
Vínculo institucional
  ├── Professor
  ├── Funcionário
  ├── Aluno
  └── Encarregado
  ↓
Conta institucional (quando aplicável)
  ↓
Autenticação Supabase
  ↓
Papel
  ↓
Permissões
  ↓
Escopo
  ↓
Operação autorizada
```

Uma pessoa pode existir sem conta. Criar uma pessoa não deve conceder acesso ao sistema.

## 2. Professor — criação

Fluxo institucional:

1. Secretaria/Direção Pedagógica cria ou seleciona a Pessoa.
2. O SIGE cria o vínculo `teachers`.
3. É atribuído um código profissional único.
4. São registados dados profissionais/emprego.
5. O professor recebe as afectações académicas autorizadas:
   Professor → Disciplina → Turma → Ano lectivo.
6. Se for necessário acesso digital, é criada a conta institucional.
7. A conta recebe o papel `TEACHER`.
8. A emissão de credencial é auditada.
9. O professor recebe instruções de primeiro acesso por canal institucional seguro.

A conta não deve ser criada antes de existir uma identidade institucional válida.

## 3. Funcionário da Secretaria

Fluxo:

1. Criar/selecionar Pessoa.
2. Criar `staff_members`.
3. Criar `employment` com função, código e período de vínculo.
4. Criar conta somente se a função exigir acesso.
5. Atribuir `SECRETARIAT` ou outro papel institucional apropriado.
6. Aplicar permissões e escopo.
7. Emitir primeiro acesso.
8. Auditar.

Não criar um papel diferente para cada funcionário.

## 4. Primeiro acesso

A emissão de credencial usa:

- identidade já criada;
- email institucional;
- password temporária criptograficamente aleatória;
- `first_access_required = true`;
- `credential_issued_at`;
- `activated_at`;
- auditoria.

A password temporária **não é armazenada pelo SIGE em texto**.

No primeiro login:

```
LOGIN
  ↓
Conta autenticada
  ↓
first_access_required = true
  ↓
Alteração obrigatória da password
  ↓
Sessão normal
```

Após sucesso:

```
first_access_required = false
```

O utilizador não deve receber acesso operacional normal enquanto a troca obrigatória estiver pendente.

## 5. Gestão posterior

Uma conta pode estar:

```
ACTIVE
SUSPENDED
```

A suspensão bloqueia o acesso sem apagar:

- pessoa;
- vínculo;
- afectações;
- notas;
- histórico;
- auditoria.

Quando um professor deixa a escola, a operação normal é:

```
Professor ACTIVE
  ↓
Afectações encerradas
  ↓
Vínculo profissional INACTIVE
  ↓
Conta SUSPENDED
```

Não apagar histórico académico.

## 6. Professor — autorização

O professor recebe somente o contexto das suas afectações.

Pode, conforme permissões e estado:

- consultar o próprio perfil;
- consultar as próprias turmas;
- consultar os próprios alunos;
- consultar as próprias disciplinas;
- lançar avaliações das suas afectações;
- alterar resultados enquanto a avaliação estiver aberta;
- consultar/generar pautas dentro do seu contexto;
- consultar horários próprios;
- operar o Livro de Ponto quando essa capacidade estiver homologada.

Não pode:

- consultar propinas;
- registar pagamentos;
- alterar permissões;
- fechar o ano lectivo;
- alterar notas de outro professor;
- alterar avaliação encerrada;
- consultar alunos fora das suas afectações.

## 7. Secretaria — autorização

A Secretaria opera o domínio administrativo:

- pessoas;
- alunos;
- responsáveis;
- matrícula;
- renovação;
- inscrição;
- formação de turmas;
- ano lectivo;
- horários;
- transferências;
- desistências;
- anulações conforme aprovação exigida.

Não recebe automaticamente:

- gestão de notas;
- gestão de fórmulas de avaliação;
- financeiro;
- relatórios institucionais globais.

## 8. Direção Pedagógica

Pode operar o domínio pedagógico:

- professores;
- afectações;
- turmas;
- disciplinas;
- avaliações;
- notas;
- pautas;
- percursos académicos.

Não possui acesso financeiro por defeito.

## 9. Financeiro

O papel `FINANCE` é separado.

Pode operar:

- obrigações;
- propinas;
- mensalidades;
- transporte financeiro;
- pagamentos;
- saldos;
- recibos;
- operações financeiras autorizadas.

Não recebe automaticamente acesso pedagógico.

## 10. Percurso A/B/C

A escolha de percurso é um dado académico histórico, não uma propriedade solta da turma.

Modelo:

```
Aluno
 ↓
Conclusão/resultado do ciclo de origem
 ↓
Elegibilidade para ciclo seguinte
 ↓
Escolha de percurso
 ├── A
 ├── B
 └── C
 ↓
Confirmação
 ↓
Turma / currículo compatível
```

O SIGE já possuía `academic_pathways` e grupos de escolha curriculares. Foi adicionada a entidade `student_pathway_selections` para preservar:

- ciclo de origem;
- ciclo destino;
- ano lectivo;
- percurso escolhido;
- estado;
- data;
- actor;
- confirmação/cancelamento;
- motivo.

Os nomes e composição dos grupos devem continuar configuráveis e sujeitos à homologação da escola. O sistema não deve transformar A/B/C em uma regra global imutável.

## 11. Regra de transição

A escolha não deve aparecer para qualquer aluno a qualquer momento.

A elegibilidade deve resultar de:

- ciclo actual;
- resultado/progressão;
- ano lectivo;
- oferta de percursos;
- regras institucionais.

A UI deve mostrar a escolha apenas quando o contexto académico permitir.

## 12. Princípio de encerramento

Ao encerrar o ano lectivo:

- contas continuam existentes;
- vínculos históricos continuam existentes;
- notas e pautas continuam imutáveis quando fechadas;
- afectações terminam conforme datas/estado;
- o novo ano lectivo recebe novos contextos;
- nenhuma identidade é apagada para "limpar" o ano.

## 13. Auditoria

Devem ser auditadas, no mínimo:

- criação de conta;
- emissão de credencial;
- primeiro acesso concluído;
- suspensão/reactivação;
- alteração de papel;
- alteração de permissão;
- alteração de escopo;
- criação/alteração/desactivação de professor;
- criação/alteração/desactivação de funcionário;
- escolha/confirmação/cancelamento de percurso.

## 14. Segurança

A autorização real não depende do frontend.

```
Frontend
  ↓
Backend / command
  ↓
Permission
  ↓
Scope
  ↓
Estado
  ↓
Integridade
  ↓
Audit
```

Esconder um botão nunca substitui a autorização no backend.
