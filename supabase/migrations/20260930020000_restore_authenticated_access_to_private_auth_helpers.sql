-- Restore the EXECUTE privileges required by RLS policies that call
-- the internal authentication helpers under the authenticated role.
-- These helpers remain in the private schema and are SECURITY DEFINER.

grant execute on function private.has_permission(text, uuid) to authenticated;
grant execute on function private.current_person_id() to authenticated;

-- Anonymous clients must never invoke authorization helpers.
revoke execute on function private.has_permission(text, uuid) from anon;
revoke execute on function private.current_person_id() from anon;
