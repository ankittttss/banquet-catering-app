-- ============================================================================
-- Phase 28 — Customer profile visibility for event handlers.
--
-- Phase 23 made operator-role profiles publicly readable but kept
-- customer profiles private to themselves + admins. That broke the
-- "who is this booking from?" question on the operator inbox and the
-- manager event-detail / inbox screens — they can see the event row
-- (post-phase 27) but not the customer's name/phone/email.
--
-- This adds a narrow read policy: a profile row is readable by a
-- non-owner if that non-owner is the banquet operator handling the
-- customer's event, OR a manager / service boy assigned to it. Same
-- SECURITY DEFINER pattern used in phase 24/27 to dodge RLS recursion.
--
-- Idempotent: every helper uses CREATE OR REPLACE; every policy drops
-- the same name first, so this file is safe to re-run.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0. Helpers — bypass RLS during the lookup so the policy stays simple.
-- ----------------------------------------------------------------------------
create or replace function public.is_customer_of_my_venue_event(
  p_customer_id uuid,
  p_uid         uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.events e
      join public.banquet_venues v on v.id = e.banquet_venue_id
     where e.user_id = p_customer_id
       and v.owner_profile_id = p_uid
  );
$$;

create or replace function public.is_customer_of_my_assigned_event(
  p_customer_id uuid,
  p_uid         uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.events e
      join public.event_assignments ea on ea.event_id = e.id
     where e.user_id = p_customer_id
       and ea.profile_id = p_uid
  );
$$;


-- ----------------------------------------------------------------------------
-- 1. profiles — narrow customer-name read for the operators/staff
--    actually handling that customer's booking.
-- ----------------------------------------------------------------------------
drop policy if exists "profiles_event_handler_read" on public.profiles;
create policy "profiles_event_handler_read"
  on public.profiles for select
  using (
       public.is_customer_of_my_venue_event(profiles.id, auth.uid())
    or public.is_customer_of_my_assigned_event(profiles.id, auth.uid())
  );
