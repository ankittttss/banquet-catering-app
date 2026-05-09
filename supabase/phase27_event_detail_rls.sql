-- ============================================================================
-- Phase 27 — RLS for event-detail screens.
--
-- The manager event-detail and operator booking-review screens need to
-- read the joined event + order + vendor-lot picture. Existing policies
-- only let:
--
--   • the customer (event owner)         read events/orders/lots
--   • the banquet operator               read events at their venues
--   • the kitchen staff                  read lots routed to their kitchen
--   • the admin                          read everything
--
-- Three holes are surfacing now:
--
--   1. Managers + service boys assigned to an event cannot SELECT the
--      `events` row → PostgREST returns NULL for the embed in
--      `event_assignments → events`, and the manager home / detail
--      screens render "Date TBD" or "Event not found".
--
--   2. Banquet operators can read events for their venue but cannot
--      SELECT the customer's `orders` row — the operator booking-review
--      screen has no bill / package data to render.
--
--   3. Same problem for `order_vendor_lots` — neither the operator nor
--      the assigned manager / service boys can see which restaurants
--      are supplying food for the event.
--
-- Why each policy below uses a SECURITY DEFINER helper:
--   The natural-looking version of these policies (exists-subquery into
--   `event_assignments` / `events`) hits the same 42P17 recursion that
--   phase 24 already had to fix on `event_assignments` itself — the
--   subquery re-fires the same SELECT policies, looping. Wrapping each
--   lookup in a SECURITY DEFINER function bypasses RLS inside the
--   subquery and leaves the outer policy a simple bool check.
--
-- Idempotent: every helper uses CREATE OR REPLACE; every policy drops
-- the same name first, so this file is safe to re-run.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0. Helpers — SECURITY DEFINER, so subqueries inside the policies don't
--    re-fire RLS and trigger recursion.
-- ----------------------------------------------------------------------------
create or replace function public.is_event_assignee(
  p_event_id uuid,
  p_uid      uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.event_assignments
     where event_id   = p_event_id
       and profile_id = p_uid
  );
$$;

create or replace function public.is_order_assignee(
  p_order_id uuid,
  p_uid      uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.orders o
      join public.event_assignments ea on ea.event_id = o.event_id
     where o.id = p_order_id
       and ea.profile_id = p_uid
  );
$$;

create or replace function public.is_event_venue_owner(
  p_event_id uuid,
  p_uid      uuid
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
     where e.id = p_event_id
       and v.owner_profile_id = p_uid
  );
$$;

create or replace function public.is_order_venue_owner(
  p_order_id uuid,
  p_uid      uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.orders o
      join public.events e         on e.id = o.event_id
      join public.banquet_venues v on v.id = e.banquet_venue_id
     where o.id = p_order_id
       and v.owner_profile_id = p_uid
  );
$$;


-- ----------------------------------------------------------------------------
-- 1. events — any profile assigned to the event can read it.
-- ----------------------------------------------------------------------------
drop policy if exists "events_assignee_read" on public.events;
create policy "events_assignee_read"
  on public.events for select
  using (public.is_event_assignee(events.id, auth.uid()));


-- ----------------------------------------------------------------------------
-- 2. orders — operator (venue owner) + assigned staff can read.
-- ----------------------------------------------------------------------------
drop policy if exists "orders_banquet_read" on public.orders;
create policy "orders_banquet_read"
  on public.orders for select
  using (public.is_event_venue_owner(orders.event_id, auth.uid()));

drop policy if exists "orders_assignee_read" on public.orders;
create policy "orders_assignee_read"
  on public.orders for select
  using (public.is_event_assignee(orders.event_id, auth.uid()));


-- ----------------------------------------------------------------------------
-- 3. order_vendor_lots — same audiences, joined through orders.
-- ----------------------------------------------------------------------------
drop policy if exists "lots_banquet_read" on public.order_vendor_lots;
create policy "lots_banquet_read"
  on public.order_vendor_lots for select
  using (public.is_order_venue_owner(order_vendor_lots.order_id, auth.uid()));

drop policy if exists "lots_assignee_read" on public.order_vendor_lots;
create policy "lots_assignee_read"
  on public.order_vendor_lots for select
  using (public.is_order_assignee(order_vendor_lots.order_id, auth.uid()));
