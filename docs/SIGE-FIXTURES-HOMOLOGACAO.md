# SIGE — Fixtures de homologação

## Objetivo

O ambiente SIGE de homologação usa uma massa de dados sintética para permitir validação real dos fluxos administrativos sem misturar dados fictícios com dados reais da escola.

## Fixture 2026/2027

A migration `20260930052000_demo_people_homologation_seed.sql` cria:

- 6 alunos;
- 6 encarregados;
- 6 relações aluno–encarregado;
- 3 professores;
- 6 matrículas anuais;
- 6 inscrições confirmadas;
- alunos distribuídos entre 7.ª, 8.ª e 9.ª classes;
- uma inscrição `TRANSFER_IN` para exercitar o fluxo de transferência.

Os identificadores nacionais e telefones da fixture são deliberadamente sintéticos e marcados com prefixos `DEMO-`.

## Regra financeira

A fixture não cria valores de propinas, mensalidades ou transporte.

Os valores financeiros devem continuar a ser configurados pela escola/gestão financeira. A existência de alunos e inscrições não deve fabricar obrigações monetárias.

## Professores

Os professores DEMO possuem código funcional e dados pessoais mínimos. Nenhum e-mail institucional é criado.

O cadastro docente continua separado da autenticação. Uma futura conta de acesso só deve ser criada quando o modelo de identidade da escola estiver definido.

## Segurança e manutenção

Esta migration é uma exceção controlada à regra de mutações command-oriented: fixtures de homologação precisam de materializar estado inicial diretamente durante a migração.

A fixture:

1. usa UUIDs determinísticos;
2. é idempotente via `on conflict`;
3. referencia a escola DEMO SIGE e o ano 2026/2027 já versionados;
4. não contém credenciais;
5. não representa dados reais de alunos, encarregados ou professores.

## Estado validado

Após a aplicação remota:

| Entidade | Registos |
|---|---:|
| Alunos | 6 |
| Encarregados | 6 |
| Relações aluno–encarregado | 6 |
| Professores | 3 |
| Matrículas | 6 |
| Inscrições | 6 |

Também foi validada a cadeia relacional aluno → encarregado → matrícula → classe → inscrição para os seis alunos.

## Próximo passo

A próxima massa de homologação deve ser construída sobre a estrutura pedagógica e financeira existente, especialmente:

- turmas;
- ofertas disciplinares;
- atribuição professor–disciplina;
- horários;
- configuração dos tipos de cobrança pela escola;
- pagamentos e saldos.

Nenhum valor financeiro deve ser inventado enquanto a configuração oficial da escola não estiver definida.
