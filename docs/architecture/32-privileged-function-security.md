# 32 — Hardening global de funções privilegiadas

Foi feita uma auditoria adicional das funções `SECURITY DEFINER`.

## Regra

Toda função privilegiada em `public` ou `private` deve:

1. definir explicitamente `search_path`;
2. preferencialmente usar `search_path = ''`;
3. qualificar referências a `public`, `private`, `auth` e demais schemas;
4. ter `EXECUTE` concedido apenas quando o contrato exige exposição;
5. nunca depender de objetos resolvidos implicitamente pelo search path.

As migrations antigas de invariantes, matrícula, avaliação e ano letivo que ainda usavam `public, auth, pg_temp` foram endurecidas.

Também foi criado teste estrutural para impedir regressão futura.