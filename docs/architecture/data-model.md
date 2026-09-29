# SIGE — Modelo físico e decisões de modelagem

O banco é o sistema de integridade dos fatos operacionais. A aplicação pode orquestrar processos, mas não deve ser a única camada capaz de impedir estados impossíveis.

## Identidade

`auth.users` é a identidade técnica de autenticação. `people` é a pessoa no domínio escolar. `students`, `teachers`, `staff_members` e `guardians` representam vínculos/contextos. `app_accounts` liga Auth a Person.

Não usar email como identidade escolar, Auth UUID como número de aluno ou user metadata como fonte de autorização.

## Matrícula e turma

```
Student
  -> StudentEnrollment (ano letivo)
      -> ClassPlacement (turma, temporal)
          -> StudentCourseParticipation
              -> CourseOffering
                  -> TeacherAssignment
```

A matrícula responde em que ano letivo o aluno está matriculado; a colocação responde em que turma esteve; a oferta responde qual disciplina é ministrada para aquela turma; a atribuição responde qual professor está responsável.

A separação é conceitualmente alinhada ao Ed-Fi, que distingue StudentSchoolAssociation, Section, StudentSectionAssociation e StaffSectionAssociation. Não copiamos o modelo; usamos a mesma separação de responsabilidades. 

## Temporalidade

Relações históricas importantes usam `starts_on` / `ends_on`. O PostgreSQL usa exclusion constraints para impedir sobreposição de colocações do mesmo aluno e atribuições duplicadas do mesmo professor/oferta. Isso protege também contra concorrência.

## Avaliação

Não existem colunas fixas como `acs1`, `acs2` ou `trabalho1`.

```
AssessmentPeriod
  -> Assessment
      -> AssessmentResult
```

O número de avaliações é representado pelos registros concretos e pelas regras versionadas. `AcademicResult` representa uma classificação calculada/homologada com versão da regra e snapshot dos inputs.

O Ed-Fi também separa gradebook, notas de período e histórico académico.

## Finanças

```
FeePlan
  -> FeePlanItem
      -> Charge
          <- PaymentAllocation <- Payment
          <- ChargeAdjustment
```

Recibo é documento associado ao pagamento. Reversão é evento próprio. Saldo é derivado, não armazenado no aluno.

Transporte é `StudentService` + dados específicos de transporte. Sem esse serviço, não há obrigação de transporte.

## Segurança

Todas as tabelas públicas têm RLS. RBAC é modelado em roles, permissions, role_permissions e account_roles. Professor recebe escopo adicional pela própria atribuição à CourseOffering.

## Auditoria

Operações sensíveis devem produzir `audit_events` com ator, escola, ação, entidade, estado anterior/posterior, motivo, request id e timestamp.

## Referências

- https://docs.ed-fi.org/reference/data-exchange/data-standard/5/model-reference/teaching-and-learning-domain/overview/
- https://docs.ed-fi.org/reference/data-exchange/data-standard/5/model-reference/enrollment-domain/overview/
- https://docs.ed-fi.org/reference/data-exchange/data-standard/5/model-reference/student-academic-record-domain/overview/
- https://www.postgresql.org/docs/current/ddl-constraints.html
- https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/api/custom-claims-and-role-based-access-control-rbac
