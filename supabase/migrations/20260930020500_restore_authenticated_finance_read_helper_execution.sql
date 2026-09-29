-- Financial read models call this internal helper from authenticated server requests.
-- Keep it private and executable only by authenticated clients through SECURITY DEFINER callers.
grant execute on function private.charge_effective_amount(uuid) to authenticated;
revoke execute on function private.charge_effective_amount(uuid) from anon;
