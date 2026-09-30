# SIGE — Fecho dos domínios académico e financeiro

## Estado

Branch de implementação: `feat/sige-administrative-lifecycle`.

Este documento regista o estado verificável do ciclo DEMO 2026/2027 após a materialização de dados pedagógicos e a abertura do fluxo de configuração/pagamento financeiro.

## 1. Cadeia académica

A cadeia operacional é:

```
Ano lectivo
  ↓
Classe
  ↓
Currículo
  ↓
Turma
  ↓
Oferta de disciplina
  ↓
Professor
  ↓
Horário
  ↓
Participação do aluno
  ↓
Avaliações
  ↓
Resultados
  ↓
Pauta
```

### Turma

`class_groups` representa a turma administrativa do ano.

A turma não contém uma lista duplicada de disciplinas. As disciplinas são derivadas por `curriculum_subjects` e materializadas como `course_offerings`.

### Professor

O professor é uma entidade de pessoa + vínculo docente.

A relação pedagógica é temporal:

`teacher_assignments.teacher_id → teacher_assignments.course_offering_id`.

O cadastro não exige e-mail institucional.

### Horário

`schedule_entries` liga:

- turma;
- oferta;
- professor;
- assignment docente;
- período;
- sala;
- dia da semana;
- intervalo de validade.

A integridade de assignment e conflitos temporais é protegida no banco.

### Aluno

A matrícula anual permanece separada da inscrição.

A colocação em turma ocorre por `class_placements`.

A participação numa disciplina ocorre por `student_course_participations`.

Isto permite transferências sem apagar o histórico.

## 2. Livro de notas

O modelo não fixa o sistema em apenas duas avaliações.

A configuração DEMO do 1.º trimestre contém:

- AC1;
- AC2;
- AC3;
- AC4;
- AT.

AC3 e AC4 podem permanecer sem nota.

A regra existente do motor calcula a média trimestral a partir das avaliações publicadas configuradas para MACS e da AT, respeitando a versão da regra académica.

Resultados oficiais continuam separados das notas de avaliação.

## 3. Exames e resultados

O domínio possui:

- sessões de exame;
- candidatos;
- avaliações do tipo EXAM;
- resultados de frequência;
- resultados finais;
- recuperação como evento explícito, sem inventar uma fórmula normativa;
- homologação;
- publicação;
- correção de resultados publicados com histórico.

A configuração de paralelismo pedagógico continua deliberadamente separada do fixture DEMO quando a informação específica da escola não está definida.

## 4. Fixture DEMO

O ambiente DEMO contém:

| Entidade | Quantidade |
|---|---:|
| Alunos | 6 |
| Encarregados | 6 |
| Professores | 8 |
| Turmas | 3 |
| Disciplinas | 8 |
| Configurações curriculares | 24 |
| Ofertas disciplinares | 24 |
| Atribuições professor-disciplina | 24 |
| Colocações em turma | 6 |
| Participações disciplinares | 48 |
| Horários | 24 |
| Períodos de avaliação | 3 |
| Avaliações | 40 |
| Resultados de avaliação publicados | 48 |

Distribuição:

- 7.ª Classe A: 2 alunos / 8 disciplinas;
- 8.ª Classe A: 2 alunos / 8 disciplinas;
- 9.ª Classe A: 2 alunos / 8 disciplinas.

Os nomes, contactos e documentos da fixture são sintéticos.

A fixture não deve ser interpretada como plano curricular oficial da escola.

## 5. Financeiro

O financeiro tem três níveis distintos:

### Configuração

A escola pode definir:

- tipos de cobrança;
- plano do ano lectivo;
- itens do plano;
- valor;
- dia de vencimento.

O SIGE não define valores financeiros por conta própria.

### Obrigações

As cobranças são derivadas de configuração explícita.

A mensalidade pode ser gerada para vários vencimentos através de `generate_monthly_tuition_charges`.

Transporte continua opcional e separado.

### Pagamento

O ciclo é:

```
Registar pagamento
      ↓
Confirmar
      ↓
Alocar a obrigação
      ↓
Emitir recibo
```

Registar um pagamento não deve, sozinho, alterar o saldo de uma obrigação.

## 6. Segurança

As read models expostas pela aplicação estão configuradas com `security_invoker=true`, permitindo que as políticas RLS das tabelas subjacentes sejam respeitadas.

As funções `SECURITY DEFINER` verificadas usam `search_path = ''` e nomes de relação qualificados.

Também foi verificado que não existem funções `SECURITY DEFINER` públicas com EXECUTE concedido ao papel `public`.

Estas verificações seguem as recomendações atuais de segurança do Supabase para RLS, views e funções. citeturn0search0turn0search2turn0search3

## 7. O que não foi inventado

Não foram fabricados:

- e-mails institucionais;
- valores oficiais de propinas;
- valores oficiais de transporte;
- plano curricular oficial da escola;
- regime de paralelismo pedagógico da escola;
- fórmula genérica de recuperação sem fonte normativa.

O DEMO apenas fornece dados sintéticos suficientes para testar o produto.

## 8. Critério de fecho

Um domínio só é considerado fechado quando:

1. existe no modelo físico;
2. possui comando ou mecanismo de escrita controlado;
3. possui read model adequado;
4. possui UI correspondente;
5. possui dados DEMO coerentes quando aplicável;
6. possui invariantes no banco;
7. foi verificado diretamente no PostgreSQL;
8. está documentado;
9. o deployment passa pela validação do CI/Vercel.

Este documento deve ser atualizado quando qualquer uma dessas condições mudar.
