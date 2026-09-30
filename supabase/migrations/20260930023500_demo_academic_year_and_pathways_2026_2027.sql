-- SIGE demo seed: academic context for homologation.
-- These are demo/configuration records, not immutable national curriculum policy.

insert into public.academic_years (school_id,label,starts_on,ends_on,status)
select '27bf14b8-0d53-4a6e-80cc-6fb2e3164bbb','2026/2027',date '2026-01-01',date '2027-12-31','OPEN'
where not exists (
  select 1 from public.academic_years
  where school_id='27bf14b8-0d53-4a6e-80cc-6fb2e3164bbb' and label='2026/2027'
);

insert into public.academic_pathways (school_id,academic_cycle_id,code,name,description,kind,active)
select '27bf14b8-0d53-4a6e-80cc-6fb2e3164bbb',c.id,v.code,v.name,v.description,'AREA',true
from public.academic_cycles c
cross join (values
 ('A','Grupo A — Comunicação e Ciências Sociais','Percurso de homologação para a área de Comunicação e Ciências Sociais.'),
 ('B','Grupo B — Matemática e Ciências Naturais','Percurso de homologação para a área de Matemática e Ciências Naturais.'),
 ('C','Grupo C — Artes Visuais e Cénicas','Percurso de homologação para a área de Artes Visuais e Cénicas.')
) v(code,name,description)
where c.code='C2'
and not exists (
 select 1 from public.academic_pathways p
 where p.academic_cycle_id=c.id and p.code=v.code
);