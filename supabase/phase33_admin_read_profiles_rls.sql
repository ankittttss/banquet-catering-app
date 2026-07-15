-- ============================================================================
-- phase33_admin_read_profiles_rls.sql
--
-- Lets an admin read ALL profiles so the admin console → Team tab can list
-- real event managers and service crew (profiles grouped by role).
--
-- A naive policy that checks `profiles.role = 'admin'` directly inside a policy
-- ON `profiles` would recurse (RLS re-evaluates on the sub-select). We use a
-- SECURITY DEFINER helper so the admin check runs with the function owner's
-- rights and bypasses that recursion.
--
-- Additive + idempotent (drops first). Safe to re-run.
-- ============================================================================

create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

drop policy if exists "admins read profiles" on public.profiles;

create policy "admins read profiles"
  on public.profiles
  for select
  to authenticated
  using (public.is_admin());
