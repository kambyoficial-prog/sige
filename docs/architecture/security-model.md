# SIGE — Modelo de segurança

## Fronteiras

```
Browser
  ↓
Next.js server/application boundary
  ↓
Supabase Auth
  ↓
PostgreSQL + RLS
  ↓
Domain data
```

Nenhuma camada substitui as outras.

## Auth ≠ authorization

Supabase Auth responde quem é a identidade. SIGE determina Person, escola, vínculo, roles, permissions e escopo.

O sistema não usa `user_metadata` para decisões de autorização.

## RLS

A regra base é deny-by-default. Cada operação relevante recebe política explícita. UPDATE deve validar a linha existente e o novo estado.

Views que precisam respeitar RLS usam `security_invoker`.

## SECURITY DEFINER

É usado apenas nas funções privadas de autorização que precisam consultar o catálogo de acesso sem recursão de RLS. Essas funções têm search_path controlado, verificam auth.uid(), ficam em schema privado e não são executáveis por public.

## Escopo do professor

O acesso de professor exige conta ativa, Person correspondente, Teacher correspondente, TeacherAssignment ativa, CourseOffering correspondente e permission adequada.

## Finanças

Pagamento confirmado não é apagado para corrigir histórico. Reversão é evento próprio.

## Auditoria

São auditáveis, entre outros:
- matrícula;
- transferência;
- cancelamento;
- publicação/correção de nota;
- obrigação financeira;
- confirmação/reversão de pagamento;
- concessão/revogação de acesso;
- fecho do ano letivo.

## Referências

- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/database/views
- https://supabase.com/docs/guides/auth/managing-user-data
- https://supabase.com/docs/guides/api/custom-claims-and-role-based-access-control-rbac
- https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- https://www.postgresql.org/docs/current/perm-functions.html
