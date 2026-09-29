-- SIGE F5 — Operations command layer
select plan(10);
select has_function('public', 'create_room', array['uuid','text','text','integer','text','text']);
select has_function('public', 'create_schedule_period', array['uuid','text','text','integer','time','time','text','text']);
select has_function('public', 'upsert_school_calendar_day', array['uuid','date','boolean','text','text','text']);
select has_function('public', 'create_schedule_entry', array['uuid','uuid','uuid','uuid','uuid','uuid','uuid','smallint','date','date','text','text','text']);
select has_function('public', 'set_schedule_entry_status', array['uuid','public.schedule_entry_status','text','text']);
select has_index('public', 'schedule_entries', 'schedule_class_no_overlap');
select has_index('public', 'schedule_entries', 'schedule_teacher_no_overlap');
select has_index('public', 'schedule_entries', 'schedule_room_no_overlap');
select ok(exists(select 1 from information_schema.tables where table_schema='public' and table_name='class_sessions'),'class session aggregate exists');
select * from finish();
