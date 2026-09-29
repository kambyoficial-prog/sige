-- SIGE F5 — class session command boundary
select plan(18);

select has_function('public', 'open_class_session', array['uuid','date','text','text','text','text']);
select has_function('public', 'close_class_session', array['uuid','text','text','text']);
select has_function('public', 'record_session_attendance', array['uuid','uuid','public.attendance_status','integer','text','text','text']);

select ok(
  exists(
    select 1 from pg_constraint
    where conrelid = 'public.class_sessions'::regclass
      and conname = 'class_sessions_status_ck'
  ),
  'class session status is constrained'
);

select ok(
  not exists(
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'class_sessions'
      and policyname = 'sessions_manage'
  ),
  'direct class session manage policy is removed'
);

select ok(
  not exists(
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'attendance_records'
      and policyname = 'attendance_manage'
  ),
  'direct attendance manage policy is removed'
);

select ok(
  not exists(
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'class_sessions'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT','UPDATE','DELETE')
  ),
  'authenticated cannot directly mutate class sessions'
);

select ok(
  not exists(
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'attendance_records'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT','UPDATE','DELETE')
  ),
  'authenticated cannot directly mutate attendance records'
);

select ok(
  exists(select 1 from pg_class where relname = 'class_session_directory' and relkind = 'v'),
  'class session directory projection exists'
);

select ok(
  exists(select 1 from pg_class where relname = 'class_session_roster' and relkind = 'v'),
  'class session roster projection exists'
);

select ok(
  coalesce(
    (select reloptions @> array['security_invoker=true']
     from pg_class where oid = 'public.class_session_directory'::regclass),
    false
  ),
  'class session directory uses invoker security'
);

select ok(
  coalesce(
    (select reloptions @> array['security_invoker=true']
     from pg_class where oid = 'public.class_session_roster'::regclass),
    false
  ),
  'class session roster uses invoker security'
);

select ok(
  position('private.has_permission' in pg_get_functiondef(
    'public.open_class_session(uuid,date,text,text,text,text)'::regprocedure
  )) > 0,
  'session opening checks authorization'
);

select ok(
  position("entry_status <> 'ACTIVE'" in pg_get_functiondef(
    'public.open_class_session(uuid,date,text,text,text,text)'::regprocedure
  )) > 0,
  'session opening requires an active schedule'
);

select ok(
  position('private.begin_command' in pg_get_functiondef(
    'public.record_session_attendance(uuid,uuid,public.attendance_status,integer,text,text,text)'::regprocedure
  )) > 0,
  'attendance recording is idempotent'
);

select ok(
  position('STUDENT_NOT_IN_CLASS' in pg_get_functiondef(
    'public.record_session_attendance(uuid,uuid,public.attendance_status,integer,text,text,text)'::regprocedure
  )) > 0,
  'attendance cannot target a student outside the class'
);

select ok(exists(select 1 from pg_policy where polname = 'teacher_students_own_classes_read' and polrelid = 'public.students'::regclass),'teacher student roster policy exists');
select ok(exists(select 1 from pg_policy where polname = 'teacher_enrollments_own_classes_read' and polrelid = 'public.student_enrollments'::regclass),'teacher enrollment roster policy exists');
select ok(exists(select 1 from pg_policy where polname = 'teacher_people_own_classes_read' and polrelid = 'public.people'::regclass),'teacher people roster policy exists');

select * from finish();
