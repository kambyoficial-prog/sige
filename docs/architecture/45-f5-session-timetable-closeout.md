# 45 — F5 vertical slice: horário → sessão → livro de ponto

## Objetivo

Fechar uma primeira operação escolar completa sem criar um módulo paralelo de frequência:

```
Horário oficial
    ↓
Entrada de horário ACTIVE
    ↓
Sessão de aula
    ↓
Livro de ponto
    ↓
Registos por aluno
    ↓
Sessão CLOSED
```

A sessão é a unidade temporal da aula. A frequência é um dado pertencente à sessão.

## O que foi implementado

### Database

- `open_class_session`
- `close_class_session`
- `record_session_attendance`
- validação de sessão contra:
  - ano letivo;
  - vigência do horário;
  - dia da semana;
  - calendário escolar;
  - entrada de horário ACTIVE;
  - professor/atribuição;
  - turma do aluno.
- idempotência via `private.begin_command`;
- auditoria via `audit_events`;
- proteção temporal do ano letivo já existente;
- remoção das políticas de escrita direta em `class_sessions` e `attendance_records`;
- revogação de INSERT/UPDATE/DELETE direto para `authenticated`.

### Read models

- `class_session_directory`
- `class_session_roster`

Ambas usam `security_invoker=true`.

### Authorization

A operação aceita:

- `operations.manage` para secretaria/direção;
- `attendance.own.manage` quando o docente é o professor efetivamente associado à sessão.

Para que o docente possa montar o seu livro sem receber leitura escolar global, foram adicionadas políticas contextuais para:

- `students`;
- `student_enrollments`;
- `people`.

O escopo é limitado aos alunos de turmas em que o docente possui uma atribuição ativa.

## Frontend

### Livro de ponto

`/livro-de-ponto` agora:

- seleciona turma;
- seleciona data;
- deriva aulas do horário oficial;
- permite abrir apenas sessões de horários ACTIVE;
- lista sessões do dia;
- abre o roster da sessão;
- permite Presente, Falta, Justificada e Atraso;
- exige minutos para atraso;
- permite fechar a sessão;
- mostra códigos de erro retornados pela camada de aplicação;
- não calcula regras de domínio no browser.

### Horários

A grelha semanal foi extraída para um componente reutilizável:

`apps/web/components/sige/timetable-grid.tsx`

Ela agora é usada pelo horário de turma e pelos perfis de professor/aluno.

### Perfil do professor

O perfil existente passou a mostrar o horário semanal do docente.

### Perfil do aluno

O perfil existente passou a mostrar o horário semanal derivado da colocação e participação pedagógica ativa.

## Contratos

Foram adicionados:

- `TeacherTimetableEntry`
- `StudentTimetableEntry`
- `ClassSessionDirectory`
- `ClassSessionRoster`
- `OpenClassSessionInput`
- `CloseClassSessionInput`
- `RecordSessionAttendanceInput`
- `AttendanceStatus`

Os nomes de RPC e o mapeamento frontend → database permanecem centralizados.

## Testes

`supabase/tests/0034_class_session_command_layer.sql` verifica:

- existência das três funções;
- constraint de estado da sessão;
- remoção das políticas de escrita direta;
- ausência de grants de mutação;
- existência das duas projeções;
- `security_invoker`;
- autorização da abertura;
- exigência de horário ACTIVE;
- idempotência;
- rejeição de aluno fora da turma;
- existência da fronteira contextual de leitura docente.

## Limites de verificação

Este bloco foi verificado estruturalmente contra o repositório e as definições SQL existentes.

A suíte pgTAP do repositório não foi executada no remoto porque o projeto não possui pgTAP instalado. Em seu lugar, os invariantes e a existência/autorização da fronteira F5 foram verificados por SQL estrutural diretamente no PostgreSQL real do SIGE.

Também não foi declarado sucesso de `pnpm typecheck`, `pnpm lint` ou `pnpm build` porque não existe execução CI observável para estes commits nesta sessão.

## Próximo gate de F5

Antes de F6:

1. executar migrations e `0034` num banco SIGE real;
2. executar Security/Performance Advisor;
3. validar RLS com pelo menos:
   - secretaria;
   - professor proprietário da sessão;
   - professor de outra turma;
   - direção;
4. browser QA do horário e livro de ponto;
5. validar responsividade e estados de erro;
6. fechar a distribuição operacional de horário por professor/aluno;
7. somente então declarar F5 encerrado.

F6 só começa depois deste gate.
