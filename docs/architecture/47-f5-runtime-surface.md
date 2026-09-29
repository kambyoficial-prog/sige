# F5 — Operational runtime surface

## Status

The F5 database boundary is deployed to the SIGE Supabase project and verified structurally.

### Authoritative runtime pieces

- `class_timetable`
- `teacher_timetable`
- `student_timetable`
- `class_session_directory`
- `class_session_roster`
- `create_room`
- `create_schedule_period`
- `upsert_school_calendar_day`
- `create_schedule_entry`
- `set_schedule_entry_status`
- `open_class_session`
- `close_class_session`
- `record_session_attendance`

Operational writes remain command/RPC based. Direct authenticated `INSERT`, `UPDATE`, and `DELETE` access is revoked for `class_sessions` and `attendance_records`.

## Frontend surfaces

- `/horarios` — timetable by class
- `/horarios/professor` — timetable by teacher
- `/horarios/aluno` — timetable by student
- `/livro-de-ponto` — session lifecycle and attendance tied to scheduled classes

All four surfaces consume existing read models. No timetable or session business rules are duplicated in the UI.

## Security verification

RLS is enabled on the previously missed curriculum tables:

- `curriculum_areas`
- `curriculum_choice_groups`

Supabase Security Advisor no longer reports these tables as RLS-disabled.

The advisor still reports informational cases where RLS is enabled without policies on intentionally command-only/internal tables, plus warnings for exposed `SECURITY DEFINER` command functions and the public `btree_gist` extension. The command functions are intentional application RPC boundaries and each must retain explicit actor/permission checks and a pinned `search_path`.

This warning class is therefore tracked as an architectural security review item, not dismissed as a false positive.

## Integrity correction

The fresh database audit exposed a duplicate unique index on `student_enrollments` caused by the historical episode migration. The database now keeps the foundation unique constraint and removes the redundant `student_enrollments_episode_uq` index.

The historical migration source was also corrected so a fresh bootstrap does not recreate the duplicate.

## Verification limitations

The remote project does not have pgTAP installed, so the repository pgTAP tests were not executed against production. Equivalent structural SQL assertions were executed against the real remote database.

Browser verification remains pending because there is currently no SIGE Vercel project connected to the available Vercel team.
