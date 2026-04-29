-- ============================================================================
-- Phase 16 — Banquet venue inbox + equipment inventory.
--
--   • Links events to the banquet venue they're hosted at.
--   • Gives banquets an accept/decline lifecycle ('banquet_status') per event.
--   • Adds `banquet_inventory` — per-venue catalog of equipment (water
--     bottles, setup packages, extra service supplies) the operator can sell
--     as line items on top of the standard food cost.
--
-- Safe to re-run.
-- ============================================================================


-- ============================================================================
-- 1. events.banquet_venue_id — which venue the event is hosted at.
--    Nullable for legacy / "no venue picked yet" events.
-- ============================================================================
alter table public.events
  add column if not exists banquet_venue_id uuid
    references public.banquet_venues(id) on delete set null;

create index if not exists idx_events_banquet_venue
  on public.events(banquet_venue_id);


-- ============================================================================
-- 2. Banquet event lifecycle — accept/decline from the operator inbox.
-- ============================================================================
do $$ begin
  create type banquet_event_status as enum (
    'pending', 'accepted', 'declined', 'cancelled', 'completed'
  );
exception when duplicate_object then null; end $$;

alter table public.events
  add column if not exists banquet_status banquet_event_status
    not null default 'pending',
  add column if not exists banquet_notes text;


-- ============================================================================
-- 3. banquet_inventory — per-venue catalog of sellable equipment/supplies.
-- ============================================================================
create table if not exists public.banquet_inventory (
  id           uuid primary key default gen_random_uuid(),
  venue_id     uuid not null references public.banquet_venues(id) on delete cascade,
  item_type    text not null, -- 'water_bottle' | 'chair' | 'setup_basic' | ...
  label        text not null,
  unit_price   numeric(10,2) not null default 0,
  per_guest    boolean not null default true,
  is_active    boolean not null default true,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  unique (venue_id, item_type)
);

create index if not exists idx_banq_inv_venue
  on public.banquet_inventory(venue_id);


-- ============================================================================
-- 4. RLS.
-- ============================================================================
alter table public.banquet_inventory enable row level security;

drop policy if exists "inv_public_read"     on public.banquet_inventory;
drop policy if exists "inv_owner_rw"        on public.banquet_inventory;
drop policy if exists "inv_admin_rw"        on public.banquet_inventory;

-- Anyone can read an active inventory list (customer sees the item in
-- checkout line items). Writes are owner- or admin-only.
create policy "inv_public_read"
  on public.banquet_inventory for select using (is_active);

create policy "inv_owner_rw"
  on public.banquet_inventory for all
  using (
    exists (
      select 1 from public.banquet_venues v
       where v.id = venue_id
         and v.owner_profile_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.banquet_venues v
       where v.id = venue_id
         and v.owner_profile_id = auth.uid()
    )
  );

create policy "inv_admin_rw"
  on public.banquet_inventory for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));


-- Events: banquet operator can read events routed to their venues.
drop policy if exists "events_banquet_read" on public.events;
create policy "events_banquet_read"
  on public.events for select
  using (
    banquet_venue_id is not null
    and exists (
      select 1 from public.banquet_venues v
       where v.id = banquet_venue_id
         and v.owner_profile_id = auth.uid()
    )
  );

-- And update (accept / decline / add notes) on their own inbox.
drop policy if exists "events_banquet_update" on public.events;
create policy "events_banquet_update"
  on public.events for update
  using (
    banquet_venue_id is not null
    and exists (
      select 1 from public.banquet_venues v
       where v.id = banquet_venue_id
         and v.owner_profile_id = auth.uid()
    )
  )
  with check (
    banquet_venue_id is not null
    and exists (
      select 1 from public.banquet_venues v
       where v.id = banquet_venue_id
         and v.owner_profile_id = auth.uid()
    )
  );


-- ============================================================================
-- 5. Realtime.
-- ============================================================================
do $$
begin
  alter publication supabase_realtime add table public.events;
exception when duplicate_object then null; end $$;

alter table public.events replica identity full;
