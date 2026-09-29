# 22 — Planeamento e distribuição de horários

## Objetivo

O SIGE deve tornar a distribuição de horários uma operação assistida e verificável.

Não queremos uma simples grelha onde a secretaria preenche células e descobre conflitos depois.

O sistema conhece previamente:

- turmas;
- disciplinas/ofertas;
- professores;
- salas;
- períodos;
- dias;
- carga necessária;
- disponibilidade;
- restrições.

## 1. Unidade de agendamento

Uma aula agendada representa:

`Turma + Oferta de disciplina + Professor + Dia + Período + Sala`

A oferta de disciplina identifica o contexto académico.

A atribuição identifica o professor responsável.

O horário identifica quando e onde aquela oferta acontece.

## 2. Restrições duras

Estas são invariantes.

### Professor

Um professor não pode lecionar duas aulas no mesmo:

`dia + período`

A restrição usa `teacher_id`, e não `teacher_assignment_id`, porque o mesmo professor pode possuir várias atribuições.

### Turma

Uma turma não pode receber duas aulas no mesmo:

`dia + período`

### Sala

Uma sala não pode receber duas aulas no mesmo:

`dia + período`

### Contexto

Uma entrada deve corresponder ao mesmo:

- ano letivo;
- escola;
- turma;
- oferta;
- professor;
- período;
- sala.

### Vigência

Uma entrada não pode ficar fora da vigência da atribuição do professor ou do ano letivo.

## 3. Restrições suaves

Estas são preferências, não bloqueios absolutos.

Exemplos:

- professor prefere manhã;
- professor prefere tarde;
- limite diário;
- carga semanal pretendida;
- evitar muitas aulas consecutivas;
- evitar janelas;
- distribuir a mesma disciplina em dias diferentes;
- evitar duas aulas da mesma disciplina consecutivas quando não necessário;
- reservar salas especializadas;
- equilibrar disciplinas pesadas e leves ao longo da semana.

Cada preferência deve possuir peso/configuração.

Não vamos transformar preferência em regra rígida sem decisão da escola.

## 4. Fluxo operacional

### Preparação

Secretaria/direção configura:

1. ano letivo;
2. calendário;
3. dias de funcionamento;
4. períodos;
5. salas;
6. turmas;
7. currículo/ofertas;
8. professores;
9. atribuições;
10. necessidades de carga.

### Distribuição

O sistema apresenta uma matriz:

`Turma × Dia × Período`

e permite:

- selecionar oferta;
- selecionar professor;
- selecionar sala;
- visualizar conflitos;
- visualizar carga;
- mover uma aula;
- duplicar padrão;
- limpar um slot;
- comparar turmas.

### Validação

Antes de publicar:

- zero conflitos de turma;
- zero conflitos de professor;
- zero conflitos de sala;
- todas as ofertas obrigatórias cobertas;
- carga verificável;
- datas válidas.

## 5. Três visões simultâneas

A secretaria precisa conseguir alternar rapidamente entre:

### Horário da turma

Mostra:

`Dia × Período → Disciplina / Professor / Sala`

### Horário do professor

Mostra:

`Dia × Período → Turma / Disciplina / Sala`

### Horário global

Mostra a ocupação de:

`Turmas + Professores + Salas`

A mesma entrada de banco alimenta as três visões.

Não duplicar horários.

## 6. Assistência de distribuição

Ao selecionar:

> Matemática — 8.ª A — Professor João

o sistema deve conseguir responder:

- quais períodos da 8.ª A estão livres?
- quais períodos do professor estão livres?
- quais salas estão livres?
- o professor já atingiu a carga diária?
- este slot cria uma janela?
- este slot deixa a disciplina excessivamente concentrada?
- existe conflito?

A interface pode então ordenar os slots por adequação.

Isso é assistência determinística, não uma decisão opaca.

## 7. Geração automática futura

O problema completo é de **constraint optimization**.

O Google OR-Tools documenta CP-SAT precisamente para problemas de scheduling com múltiplas restrições e preferências. citeturn5search0turn5search1

Portanto, se o SIGE chegar a uma escola com centenas de professores/turmas, o caminho técnico será:

`SIGE → modelo de problema → solver → solução candidata → validação → revisão humana → publicação`

Não:

`SIGE → IA inventa horário → publicação`

A solução gerada deverá continuar sujeita às mesmas constraints PostgreSQL.

## 8. Human-in-the-loop

Mesmo com geração automática, a direção/secretaria deve poder:

- gerar;
- visualizar;
- comparar;
- aceitar;
- alterar;
- rejeitar;
- publicar.

Uma solução automática nunca será a fonte de verdade.

O horário publicado continua sendo o registo operacional do SIGE.

## 9. Métricas

O sistema poderá apresentar:

- aulas previstas;
- aulas distribuídas;
- slots livres;
- conflitos;
- carga por professor;
- carga por turma;
- ocupação de salas;
- janelas de professores;
- concentração por disciplina;
- cobertura curricular.

Estas métricas devem explicar o estado do horário; não são apenas cartões num dashboard.

## 10. Por que não implementar o solver agora

Ainda faltam dados da escola:

- duração real dos tempos;
- dias de funcionamento;
- intervalos;
- turnos;
- número de tempos por dia;
- carga horária por disciplina;
- disponibilidade dos professores;
- salas especiais;
- regras de distribuição;
- aulas duplas;
- aulas práticas;
- situações de blocos.

Sem esses dados, um solver produziria uma solução tecnicamente válida mas operacionalmente errada.

Primeiro fechamos o modelo e a experiência de distribuição. Depois parametrizamos o solver.

## 11. Decisão

A arquitetura do SIGE fica preparada para três níveis:

### Nível 1 — Manual assistido

Secretaria arrasta/seleciona.

O sistema impede erros.

### Nível 2 — Sugestão

O sistema apresenta os melhores slots disponíveis segundo regras configuradas.

### Nível 3 — Otimização

Um solver gera uma proposta completa respeitando constraints duras e maximizando preferências.

Todos os níveis usam a mesma fonte de verdade.

## Referências

- Google OR-Tools — Constraint Optimization. citeturn5search1
- Google OR-Tools — Scheduling / Employee Scheduling. citeturn5search0turn5search2
- Ed-Fi Bell Schedule Domain — períodos, calendários e horários. citeturn4search1turn4search7
