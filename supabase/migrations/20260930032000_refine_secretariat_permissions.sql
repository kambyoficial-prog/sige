-- Secretariat is operational administration, not financial administration.
delete from public.role_permissions rp
using public.permissions p, public.roles r
where rp.permission_id=p.id and rp.role_id=r.id and r.code='SECRETARIAT'
  and p.code in ('finance.manage','finance.read','administration.manage');
