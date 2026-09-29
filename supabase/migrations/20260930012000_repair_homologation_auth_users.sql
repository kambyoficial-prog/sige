-- Repairs legacy/manual homologation users so GoTrue can resolve them by email.
-- No credentials are stored here. Password hashes remain in auth.users.
UPDATE auth.users
SET
  instance_id = '00000000-0000-0000-0000-000000000000',
  confirmation_token = COALESCE(confirmation_token, ''),
  recovery_token = COALESCE(recovery_token, ''),
  email_change = COALESCE(email_change, ''),
  email_change_token_new = COALESCE(email_change_token_new, ''),
  raw_app_meta_data = jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
  updated_at = now()
WHERE email IN (
  'direccao.geral@sige.test',
  'direccao.adjunta@sige.test',
  'direccao.pedagogica@sige.test'
);
