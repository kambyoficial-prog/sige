-- SIGE security gate
-- The curriculum read policies already exist in 20260929192000_curriculum_engine.
-- This migration only enables RLS on the two tables so those policies become
-- effective. It must be applied before the SIGE environment is exposed.

alter table public.curriculum_areas enable row level security;
alter table public.curriculum_choice_groups enable row level security;
