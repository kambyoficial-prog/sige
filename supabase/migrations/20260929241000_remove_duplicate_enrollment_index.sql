-- SIGE security/performance hardening
-- The foundation unique constraint already enforces
-- (student_id, academic_year_id, enrollment_sequence). The later episode
-- migration accidentally created an identical second index.

drop index if exists public.student_enrollments_episode_uq;
