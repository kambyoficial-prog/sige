-- SIGE 0046 — Identity uniqueness hardening

create unique index if not exists people_national_id_uq
  on public.people (national_id)
  where national_id is not null and length(trim(national_id)) > 0;

create unique index if not exists guardians_school_identity_number_uq
  on public.guardians (school_id, identity_number)
  where identity_number is not null and length(trim(identity_number)) > 0;
