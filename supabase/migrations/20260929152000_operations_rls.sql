-- SIGE 0009 — Operations RLS policies

create policy calendar_read on public.school_calendar_days
  for select to authenticated
  using (
    exists (
      select 1 from public.academic_years ay
      where ay.id = school_calendar_days.academic_year_id
        and (select private.has_permission('operations.read', ay.school_id))
    )
  );

create policy calendar_manage on public.school_calendar_days
  for all to authenticated
  using (
    exists (
      select 1 from public.academic_years ay
      where ay.id = school_calendar_days.academic_year_id
        and (select private.has_permission('operations.manage', ay.school_id))
    )
  )
  with check (
    exists (
      select 1 from public.academic_years ay
      where ay.id = school_calendar_days.academic_year_id
        and (select private.has_permission('operations.manage', ay.school_id))
    )
  );

create policy rooms_read on public.rooms
  for select to authenticated
  using ((select private.has_permission('operations.read', school_id)));

create policy rooms_manage on public.rooms
  for all to authenticated
  using ((select private.has_permission('operations.manage', school_id)))
  with check ((select private.has_permission('operations.manage', school_id)));

create policy periods_read on public.schedule_periods
  for select to authenticated
  using ((select private.has_permission('operations.read', school_id)));

create policy periods_manage on public.schedule_periods
  for all to authenticated
  using ((select private.has_permission('operations.manage', school_id)))
  with check ((select private.has_permission('operations.manage', school_id)));

create policy schedule_read on public.schedule_entries
  for select to authenticated
  using (
    (select private.has_permission('operations.read', school_id))
    or exists (
      select 1
      from public.teacher_assignments ta
      join public.teachers t on t.id = ta.teacher_id
      where ta.id = schedule_entries.teacher_assignment_id
        and t.person_id = (select private.current_person_id())
        and ta.active
    )
  );

create policy schedule_manage on public.schedule_entries
  for all to authenticated
  using ((select private.has_permission('operations.manage', school_id)))
  with check ((select private.has_permission('operations.manage', school_id)));

create policy sessions_read on public.class_sessions
  for select to authenticated
  using (
    exists (
      select 1 from public.course_offerings co
      where co.id = class_sessions.course_offering_id
        and (
          (select private.has_permission('operations.read', co.school_id))
          or (
            (select private.has_permission('attendance.own.manage', co.school_id))
            and exists (
              select 1 from public.teachers t
              where t.id = class_sessions.teacher_id
                and t.person_id = (select private.current_person_id())
            )
          )
        )
    )
  );

create policy sessions_manage on public.class_sessions
  for all to authenticated
  using (
    exists (
      select 1 from public.course_offerings co
      where co.id = class_sessions.course_offering_id
        and (
          (select private.has_permission('operations.manage', co.school_id))
          or (
            (select private.has_permission('attendance.own.manage', co.school_id))
            and exists (
              select 1 from public.teachers t
              where t.id = class_sessions.teacher_id
                and t.person_id = (select private.current_person_id())
            )
          )
        )
    )
  )
  with check (
    exists (
      select 1 from public.course_offerings co
      where co.id = class_sessions.course_offering_id
        and (
          (select private.has_permission('operations.manage', co.school_id))
          or (
            (select private.has_permission('attendance.own.manage', co.school_id))
            and exists (
              select 1 from public.teachers t
              where t.id = class_sessions.teacher_id
                and t.person_id = (select private.current_person_id())
            )
          )
        )
    )
  );

create policy attendance_read on public.attendance_records
  for select to authenticated
  using (
    exists (
      select 1
      from public.class_sessions cs
      join public.course_offerings co on co.id = cs.course_offering_id
      where cs.id = attendance_records.class_session_id
        and (
          (select private.has_permission('operations.read', co.school_id))
          or (
            (select private.has_permission('attendance.own.manage', co.school_id))
            and exists (
              select 1 from public.teachers t
              where t.id = cs.teacher_id
                and t.person_id = (select private.current_person_id())
            )
          )
        )
    )
  );

create policy attendance_manage on public.attendance_records
  for all to authenticated
  using (
    exists (
      select 1
      from public.class_sessions cs
      join public.course_offerings co on co.id = cs.course_offering_id
      where cs.id = attendance_records.class_session_id
        and (
          (select private.has_permission('operations.manage', co.school_id))
          or (
            (select private.has_permission('attendance.own.manage', co.school_id))
            and exists (
              select 1 from public.teachers t
              where t.id = cs.teacher_id
                and t.person_id = (select private.current_person_id())
            )
          )
        )
    )
  )
  with check (
    exists (
      select 1
      from public.class_sessions cs
      join public.course_offerings co on co.id = cs.course_offering_id
      where cs.id = attendance_records.class_session_id
        and (
          (select private.has_permission('operations.manage', co.school_id))
          or (
            (select private.has_permission('attendance.own.manage', co.school_id))
            and exists (
              select 1 from public.teachers t
              where t.id = cs.teacher_id
                and t.person_id = (select private.current_person_id())
            )
          )
        )
    )
  );

revoke delete on public.school_calendar_days from authenticated;
revoke delete on public.rooms from authenticated;
revoke delete on public.schedule_periods from authenticated;
revoke delete on public.schedule_entries from authenticated;
revoke delete on public.class_sessions from authenticated;
revoke delete on public.attendance_records from authenticated;
