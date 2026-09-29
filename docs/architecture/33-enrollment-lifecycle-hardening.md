# 33 — Hardening do lifecycle de matrícula

O comando de matrícula já possuía boa separação entre aluno, matrícula anual e colocação em turma. A auditoria adicionou uma invariável importante:

`class_placement.starts_on/ends_on` deve permanecer dentro das datas do ano letivo da matrícula.

Isso evita um registro temporalmente impossível, como uma colocação em turma iniciada antes do ano ou prolongada depois do seu encerramento.

Também foi confirmado que:

- aluno e ano devem pertencer à mesma escola;
- matrícula ativa sobreposta é rejeitada;
- matrícula e turma devem ter o mesmo ano e classe;
- capacidade da turma é verificada sob lock da turma;
- concorrência de matrícula é serializada pelo lock do aluno;
- comandos usam idempotência e auditoria.