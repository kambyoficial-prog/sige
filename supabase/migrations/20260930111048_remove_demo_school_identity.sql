-- Production institutional identity: remove homologation/demo labels from the active school record.
update public.schools
set code = 'SIGE', name = 'SIGE', short_name = 'SIGE'
where code = 'SIGE-DEMO' and name = 'DEMO SIGE';
