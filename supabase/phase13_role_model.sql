-- ============================================================================
-- Phase 13 — Role model foundations.
--
-- Expands `profiles.role` from {user, admin, delivery} to:
--   customer | banquet | restaurant | service_boy | manager | admin
--
-- Adds ownership + hierarchy tables:
--   - banquet_venues       — a banquet login owns 1..N venues.
--   - restaurant_staff     — a restaurant login is linked to 1..N kitchens.
--   - profiles.reports_to_manager_id — staff tree (service_boy → manager).
--
-- Adds helper functions for role checks used in RLS throughout later phases.
--
-- Safe to re-run.
-- ============================================================================


-- ============================================================================
-- 1. Role column: widen the CHECK constraint, migrate legacy values.
-- ============================================================================

-- Drop the old check constraint so we can rewrite values first.
alter table public.profiles
  drop constraint if exists profiles_role_check;

-- Migrate legacy role values.
--   'user'     -> 'customer'
--   'delivery' -> 'service_boy'  (closest operational equivalent; admins can
--                                  retag mock drivers manually if they want)
update public.profiles set role = 'customer'    where role = 'user';
update public.profiles set role = 'service_boy' where role = 'delivery';

-- Install the new constraint.
alter table public.profiles
  add constraint profiles_role_check
  check (role in (
    'customer', 'banquet', 'restaurant', 'service_boy', 'manager', 'admin'
  ));

-- New default for brand-new profile rows created by the auth trigger.
alter table public.profiles
  alter column role set default 'customer';


-- ============================================================================
-- 2. Staff hierarchy: service_boy → manager link.
-- ============================================================================

alter table public.profiles
  add column if not exists reports_to_manager_id uuid
    references public.profiles(id) on delete set null;

create index if not exists idx_profiles_reports_to
  on public.profiles(reports_to_manager_id);


-- ============================================================================
-- 3. Banquet venues — one operator owns N venues.
-- ============================================================================

create table if not exists public.banquet_venues (
  id               uuid primary key default gen_random_uuid(),
  owner_profile_id uuid not null references public.profiles(id) on delete cascade,
  name             text not null,
  address          text,
  latitude         numeric(9,6),
  longitude        numeric(9,6),
  capacity         int,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now()
);
create index if not exists idx_banquet_venues_owner
  on public.banquet_venues(owner_profile_id);


-- ============================================================================
-- 4. Restaurant staff — a restaurant login can manage N kitchens.
--    (Existing `restaurants` table stays as-is; this is the join table.)
-- ============================================================================

create table if not exists public.restaurant_staff (
  id            uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  profile_id    uuid not null references public.profiles(id)    on delete cascade,
  created_at    timestamptz not null default now(),
  unique (restaurant_id, profile_id)
);
create index if not exists idx_restaurant_staff_profile
  on public.restaurant_staff(profile_id);


-- ============================================================================
-- 5. Role helper functions — used by RLS across all later phases.
--    SECURITY DEFINER to avoid RLS recursion when a policy on profiles
--    itself needs to check the caller's role.
-- ============================================================================

create or replace function public.profile_role(uid uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = uid limit 1;
$$;

create or replace function public.is_role(uid uuid, want text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.profile_role(uid) = want;
$$;

create or replace function public.is_banquet(uid uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select public.profile_role(uid) = 'banquet'; $$;

create or replace function public.is_restaurant_staff(uid uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select public.profile_role(uid) = 'restaurant'; $$;

create or replace function public.is_manager(uid uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select public.profile_role(uid) = 'manager'; $$;

create or replace function public.is_service_boy(uid uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select public.profile_role(uid) = 'service_boy'; $$;

-- is_admin() already exists from schema.sql. Leave it alone.


-- ============================================================================
-- 6. RLS — new tables.
-- ============================================================================

-- banquet_venues
alter table public.banquet_venues enable row level security;

drop policy if exists "venues_public_read"   on public.banquet_venues;
drop policy if exists "venues_owner_rw"      on public.banquet_venues;
drop policy if exists "venues_admin_write"   on public.banquet_venues;

create policy "venues_public_read"
  on public.banquet_venues for select using (true);

create policy "venues_owner_rw"
  on public.banquet_venues for all
  using (auth.uid() = owner_profile_id)
  with check (auth.uid() = owner_profile_id);

create policy "venues_admin_write"
  on public.banquet_venues for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));


-- restaurant_staff
alter table public.restaurant_staff enable row level security;

drop policy if exists "rstaff_self_read"    on public.restaurant_staff;
drop policy if exists "rstaff_admin_write"  on public.restaurant_staff;

create policy "rstaff_self_read"
  on public.restaurant_staff for select
  using (auth.uid() = profile_id or public.is_admin(auth.uid()));

create policy "rstaff_admin_write"
  on public.restaurant_staff for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));


-- profiles — add a policy so managers can read their reports, and admins
-- can update role/hierarchy. Existing policies from schema.sql still apply.
drop policy if exists "profiles_manager_read_reports" on public.profiles;
create policy "profiles_manager_read_reports"
  on public.profiles for select
  using (
    public.is_manager(auth.uid())
    and reports_to_manager_id = auth.uid()
  );

drop policy if exists "profiles_admin_update_all" on public.profiles;
create policy "profiles_admin_update_all"
  on public.profiles for update
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));
