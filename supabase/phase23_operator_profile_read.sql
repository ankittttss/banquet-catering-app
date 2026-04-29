-- ============================================================================
-- Phase 23 — Let operator roles read other operator profiles.
--
-- Bug surfaced in banquet UI: "Assign manager" sheet was empty. Root cause:
-- the only profile-read policies were (a) your own row, (b) admin-read-all,
-- (c) manager-reads-their-reports. A banquet operator querying
-- `profiles WHERE role='manager'` got zero rows back.
--
-- Fix: operator-role rows are public to other authenticated users. Customer
-- rows stay private. This matches how Uber / Swiggy expose driver names to
-- customers without exposing anything about other customers.
--
-- Safe to re-run.
-- ============================================================================

-- Any authenticated user may read profile rows whose role is an operator role.
-- Customer rows remain protected by `profiles_self_read` / admin-only.
drop policy if exists "profiles_operators_public_read" on public.profiles;
create policy "profiles_operators_public_read"
  on public.profiles for select
  using (
    auth.uid() is not null
    and role in ('banquet','restaurant','manager','service_boy','admin')
  );

-- Verify (uncomment after running):
-- select role, count(*) from public.profiles group by role order by role;
