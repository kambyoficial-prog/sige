# SIGE — Workflow de avaliação e publicação

**Status:** accepted  
**Date:** 2026-09-29

## Responsabilidades

### Professor
Pode:
- consultar a sua oferta;
- consultar avaliações próprias;
- lançar resultados apenas na sua oferta activa.

Não pode:
- publicar resultados;
- corrigir resultados publicados;
- alterar avaliações de outra oferta.

### Direção Pedagógica / perfil autorizado
Pode:
- criar avaliações;
- publicar;
- corrigir resultados publicados;
- supervisionar resultados.

## Lifecycle

`DRAFT -> OPEN -> PUBLISHED`

Resultado:

`MISSING -> ENTERED/ABSENT/EXCUSED -> PUBLISHED`

Correção:

`PUBLISHED -> correction command -> PUBLISHED`

A correção não apaga o valor anterior; cria revisão no histórico.

## Publicação

Antes de publicar:
1. verificar oferta;
2. verificar período;
3. determinar participantes activos na data da avaliação;
4. garantir que cada participante possui resultado não-MISSING;
5. publicar resultados;
6. publicar a avaliação;
7. auditar a operação.

## Regra de segurança

Não existe edição directa de `assessment_results` ou `assessments` pelo Data API autenticado.

As mutações críticas passam por commands.

## Regra matemática

`raw_score` é o valor original.

`normalized_score = raw_score / max_score * 20`

O cálculo da média oficial permanece separado e depende da versão da regra académica aplicável.
