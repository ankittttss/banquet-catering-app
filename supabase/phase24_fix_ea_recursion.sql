-- ============================================================================
-- Phase 24 — Fix "infinite recursion detected in policy" on event_assignments.
--
-- Phase 17's `ea_manager_read` and `ea_manager_rw` policies both do a subquery
-- against `event_assignments` to check "am I the manager of this event?".
-- Postgres re-applies the same SELECT policy on the subquery, which does the
-- subquery again, and so on — 42P17 infinite recursion.
--
-- Fix: wrap the lookup in a SECURITY DEFINER function so the subquery runs
-- with policy checking bypassed, and the outer policy becomes a simple bool.
--
-- Safe to re-run.
-- ============================================================================

create or replace function public.is_event_manager(p_event_id uuid, p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.event_assignments
     where event_id      = p_event_id
       and role_on_event = 'manager'
       and profile_id    = p_uid
  );
$$;


-- Rebuild the recursive policies.
drop policy if exists "ea_manager_read" on public.event_assignments;
create policy "ea_manager_read"
  on public.event_assignments for select
  using (public.is_event_manager(event_id, auth.uid()));

drop policy if exists "ea_manager_rw" on public.event_assignments;
create policy "ea_manager_rw"
  on public.event_assignments for all
  using (
    role_on_event = 'service_boy'
    and public.is_event_manager(event_id, auth.uid())
  )
  with check (
    role_on_event = 'service_boy'
    and public.is_event_manager(event_id, auth.uid())
  );
