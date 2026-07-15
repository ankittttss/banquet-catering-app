-- ============================================================================
-- phase32_admin_menu_write_rls.sql
--
-- Lets an admin insert / update / delete rows in `menu_items` from the app's
-- admin "Menu & restaurants" editor. Customer reads are already handled by the
-- existing SELECT policy; this only adds write access for admins.
--
-- "Admin" is identified by profiles.role = 'admin' (see UserRole.dbValue in
-- lib/data/models/user_role.dart).
--
-- Policies are PERMISSIVE, so this is purely additive — it does not affect the
-- existing customer-facing SELECT policy. Idempotent: drops first, safe to
-- re-run. It does NOT toggle RLS on/off (menu_items already has RLS enabled,
-- since the storefront reads it through a policy).
-- ============================================================================

drop policy if exists "admins manage menu_items" on public.menu_items;

create policy "admins manage menu_items"
  on public.menu_items
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin'
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin'
    )
  );
