-- ============================================================================
-- Phase 17 — Event staffing (manager + service boys).
--
--   • `event_assignments` — one row per (event, profile, role_on_event).
--     Manager is assigned by the banquet operator; service boys are pulled
--     from the manager's reports (profiles.reports_to_manager_id).
--   • Check-in / check-out timestamps live on the row.
--
-- Safe to re-run.
-- ============================================================================

do $$ begin
  create type event_assignment_role as enum ('manager', 'service_boy');
exception when duplicate_object then null; end $$;


create table if not exists public.event_assignments (
  id              uuid primary key default gen_random_uuid(),
  event_id        uuid not null references public.events(id)   on delete cascade,
  profile_id      uuid not null references public.profiles(id) on delete cascade,
  role_on_event   event_assignment_role not null,
  assigned_by     uuid references public.profiles(id) on delete set null,
  assigned_at     timestamptz not null default now(),
  checked_in_at   timestamptz,
  checked_out_at  timestamptz,
  notes           text,
  unique (event_id, profile_id, role_on_event)
);

create index if not exists idx_event_assignments_event
  on public.event_assignments(event_id);
create index if not exists idx_event_assignments_profile
  on public.event_assignments(profile_id);


-- ============================================================================
-- Constraint: only one manager per event.
-- ============================================================================
create unique index if not exists ux_event_single_manager
  on public.event_assignments(event_id)
  where role_on_event = 'manager';


-- ============================================================================
-- RLS.
-- ============================================================================
alter table public.event_assignments enable row level security;

drop policy if exists "ea_self_read"       on public.event_assignments;
drop policy if exists "ea_manager_read"    on public.event_assignments;
drop policy if exists "ea_banquet_rw"      on public.event_assignments;
drop policy if exists "ea_manager_rw"      on public.event_assignments;
drop policy if exists "ea_service_update"  on public.event_assignments;
drop policy if exists "ea_admin_rw"        on public.event_assignments;

-- Anyone assigned to the event reads their own row.
create policy "ea_self_read"
  on public.event_assignments for select
  using (auth.uid() = profile_id);

-- Manager reads every assignment on events they manage.
create policy "ea_manager_read"
  on public.event_assignments for select
  using (
    exists (
      select 1 from public.event_assignments ea2
       where ea2.event_id = event_assignments.event_id
         and ea2.role_on_event = 'manager'
         and ea2.profile_id = auth.uid()
    )
  );

-- Banquet operator can assign/remove staff on events for their venues.
create policy "ea_banquet_rw"
  on public.event_assignments for all
  using (
    exists (
      select 1 from public.events e
        join public.banquet_venues v on v.id = e.banquet_venue_id
       where e.id = event_assignments.event_id
         and v.owner_profile_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.events e
        join public.banquet_venues v on v.id = e.banquet_venue_id
       where e.id = event_assignments.event_id
         and v.owner_profile_id = auth.uid()
    )
  );

-- Manager can add/remove service-boy assignments on events they manage.
create policy "ea_manager_rw"
  on public.event_assignments for all
  using (
    role_on_event = 'service_boy'
    and exists (
      select 1 from public.event_assignments mgr
       where mgr.event_id = event_assignments.event_id
         and mgr.role_on_event = 'manager'
         and mgr.profile_id = auth.uid()
    )
  )
  with check (
    role_on_event = 'service_boy'
    and exists (
      select 1 from public.event_assignments mgr
       where mgr.event_id = event_assignments.event_id
         and mgr.role_on_event = 'manager'
         and mgr.profile_id = auth.uid()
    )
  );

-- Service boy may update their own check-in / check-out timestamps.
create policy "ea_service_update"
  on public.event_assignments for update
  using (auth.uid() = profile_id)
  with check (auth.uid() = profile_id);

create policy "ea_admin_rw"
  on public.event_assignments for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));


-- ============================================================================
-- Realtime for staff dashboards.
-- ============================================================================
do $$
begin
  alter publication supabase_realtime add table public.event_assignments;
exception when duplicate_object then null; end $$;

alter table public.event_assignments replica identity full;
