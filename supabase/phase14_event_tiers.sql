-- ============================================================================
-- Phase 14 — Event tiers + budget-filtered restaurant picker.
--
-- Customers pick a tier (Budget / Standard / Premium) at event-creation time.
-- Each tier carries a per-guest price band; the restaurant picker then filters
-- kitchens whose own per-guest pricing overlaps the tier's band, plus (when
-- coords are available) proximity to the event location.
--
-- Safe to re-run.
-- ============================================================================


-- ============================================================================
-- 1. event_tiers — admin-managed catalog.
-- ============================================================================
create table if not exists public.event_tiers (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  label          text not null,
  description    text,
  per_guest_min  numeric(10,2) not null,
  per_guest_max  numeric(10,2) not null,
  sort_order     int not null default 0,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  constraint event_tiers_price_band_sane
    check (per_guest_max >= per_guest_min and per_guest_min >= 0)
);

insert into public.event_tiers (code, label, description, per_guest_min, per_guest_max, sort_order)
values
  ('budget',   'Budget Bite',    '1 starter + 1 main + 1 dessert',           120,  220, 1),
  ('standard', 'Classic Meal',   '2 starters + 2 mains + 1 dessert',         220,  380, 2),
  ('premium',  'Premium Feast',  '4 starters + 3 mains + 2 desserts + drinks', 380, 700, 3)
on conflict (code) do update set
  label         = excluded.label,
  description   = excluded.description,
  per_guest_min = excluded.per_guest_min,
  per_guest_max = excluded.per_guest_max,
  sort_order    = excluded.sort_order;


-- ============================================================================
-- 2. restaurants — add per-guest price band.
--    Backfill from existing price_per_plate when present; otherwise a safe
--    default that keeps the kitchen visible in all tiers.
-- ============================================================================
alter table public.restaurants
  add column if not exists per_guest_price_min numeric(10,2),
  add column if not exists per_guest_price_max numeric(10,2);

-- Seed price bands from the legacy per-plate value so existing kitchens aren't
-- orphaned when the filter kicks in.
update public.restaurants
   set per_guest_price_min = greatest( (price_per_plate * 0.80)::numeric(10,2), 120),
       per_guest_price_max = greatest((price_per_plate * 1.30)::numeric(10,2), 250)
 where per_guest_price_min is null
   and price_per_plate is not null;

-- For anything still null (no price_per_plate), open the band wide so they
-- show up regardless of tier. Admins can tighten manually.
update public.restaurants
   set per_guest_price_min = 120,
       per_guest_price_max = 900
 where per_guest_price_min is null;


-- ============================================================================
-- 3. events — record the chosen tier.
-- ============================================================================
alter table public.events
  add column if not exists tier_id uuid references public.event_tiers(id);

create index if not exists idx_events_tier on public.events(tier_id);


-- ============================================================================
-- 4. RPC — restaurants_for_event(tier_id, lat, lng, radius_km).
--
-- Returns active restaurants whose per-guest price band overlaps the tier's
-- band, optionally scoped to a radius from (lat, lng). Ordered by distance
-- when coords are given, else by rating.
-- ============================================================================
create or replace function public.restaurants_for_event(
  p_tier_id    uuid,
  p_lat        numeric default null,
  p_lng        numeric default null,
  p_radius_km  numeric default 25
)
returns table (
  id                  uuid,
  name                text,
  logo_url            text,
  delivery_charge     numeric,
  is_active           boolean,
  price_per_plate     numeric,
  min_guests          int,
  delivery_min_minutes int,
  delivery_max_minutes int,
  rating              numeric,
  ratings_count       int,
  cuisines_display    text,
  hero_bg_hex         text,
  hero_emoji          text,
  tag                 text,
  is_pure_veg         boolean,
  popularity_score    int,
  latitude            numeric,
  longitude           numeric,
  address             text,
  per_guest_price_min numeric,
  per_guest_price_max numeric,
  distance_km         numeric
)
language sql
stable
security definer
set search_path = public
as $$
  with tier as (
    select per_guest_min, per_guest_max
      from public.event_tiers
     where id = p_tier_id
  )
  select
    r.id, r.name, r.logo_url, r.delivery_charge, r.is_active,
    r.price_per_plate, r.min_guests,
    r.delivery_min_minutes, r.delivery_max_minutes,
    r.rating, r.ratings_count,
    r.cuisines_display, r.hero_bg_hex, r.hero_emoji, r.tag,
    r.is_pure_veg, r.popularity_score,
    r.latitude, r.longitude, r.address,
    r.per_guest_price_min, r.per_guest_price_max,
    case
      when p_lat is not null and p_lng is not null
           and r.latitude is not null and r.longitude is not null
      then
        round(
          (ST_DistanceSphere(
            ST_MakePoint(r.longitude::float8, r.latitude::float8),
            ST_MakePoint(p_lng::float8,       p_lat::float8)
          ) / 1000)::numeric,
          2
        )
      else null
    end as distance_km
  from public.restaurants r
  cross join tier
  where r.is_active
    and r.per_guest_price_min <= tier.per_guest_max
    and r.per_guest_price_max >= tier.per_guest_min
    and (
      p_lat is null or p_lng is null
      or r.latitude is null or r.longitude is null
      or ST_DistanceSphere(
           ST_MakePoint(r.longitude::float8, r.latitude::float8),
           ST_MakePoint(p_lng::float8,       p_lat::float8)
         ) <= (p_radius_km * 1000)
    )
  order by
    case when p_lat is not null and p_lng is not null
              and r.latitude is not null and r.longitude is not null
         then ST_DistanceSphere(
                ST_MakePoint(r.longitude::float8, r.latitude::float8),
                ST_MakePoint(p_lng::float8,       p_lat::float8)
              )
         else null
    end asc nulls last,
    r.rating desc nulls last,
    r.popularity_score desc;
$$;


-- ============================================================================
-- 5. RLS.
-- ============================================================================
alter table public.event_tiers enable row level security;

drop policy if exists "tiers_public_read"    on public.event_tiers;
drop policy if exists "tiers_admin_write"    on public.event_tiers;

create policy "tiers_public_read"
  on public.event_tiers for select using (true);

create policy "tiers_admin_write"
  on public.event_tiers for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));
