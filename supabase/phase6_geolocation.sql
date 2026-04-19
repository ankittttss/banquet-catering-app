-- ============================================================================
-- Phase 6 — geolocation support.
--   • Enables PostGIS extension for geospatial queries.
--   • Adds latitude, longitude columns to restaurants + user_addresses.
--   • Adds a generated `location` geography column on restaurants.
--   • Adds `restaurants_near(lat, lng, radius_km)` RPC.
--
-- Run once in the Supabase SQL Editor. Safe to re-run (idempotent).
-- ============================================================================


-- ============================================================================
-- 1. PostGIS extension (Supabase-managed — no version pin).
-- ============================================================================
create extension if not exists postgis;


-- ============================================================================
-- 2. Restaurants — lat/lng + derived geography column + spatial index.
-- ============================================================================
alter table public.restaurants
  add column if not exists latitude   double precision,
  add column if not exists longitude  double precision,
  add column if not exists address    text;

-- Generated geography column — always kept in sync with lat/lng.
do $$ begin
  alter table public.restaurants
    add column location geography(Point, 4326)
      generated always as (
        case
          when latitude is not null and longitude is not null
            then st_setsrid(st_makepoint(longitude, latitude), 4326)::geography
          else null
        end
      ) stored;
exception when duplicate_column then null; end $$;

create index if not exists idx_restaurants_location
  on public.restaurants using gist(location);


-- ============================================================================
-- 3. User addresses — lat/lng columns.
-- ============================================================================
alter table public.user_addresses
  add column if not exists latitude   double precision,
  add column if not exists longitude  double precision,
  add column if not exists short_label text;   -- e.g. "Banjara Hills, Hyderabad"


-- ============================================================================
-- 4. Keep `upsert_address` compatible — accept optional lat/lng.
--    Old callers still work (two extra params default to NULL).
-- ============================================================================
create or replace function public.upsert_address(
  p_id          uuid,
  p_label       text,
  p_address     text,
  p_is_default  boolean,
  p_latitude    double precision default null,
  p_longitude   double precision default null,
  p_short_label text default null
) returns public.user_addresses
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.user_addresses;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_is_default then
    update public.user_addresses
       set is_default = false, updated_at = now()
     where user_id = v_uid and is_default
       and (p_id is null or id <> p_id);
  end if;

  if p_id is null then
    insert into public.user_addresses
      (user_id, label, full_address, is_default,
       latitude, longitude, short_label)
    values
      (v_uid, p_label, p_address, coalesce(p_is_default, false),
       p_latitude, p_longitude, p_short_label)
    returning * into v_row;
  else
    update public.user_addresses
       set label        = p_label,
           full_address = p_address,
           is_default   = coalesce(p_is_default, is_default),
           latitude     = coalesce(p_latitude, latitude),
           longitude    = coalesce(p_longitude, longitude),
           short_label  = coalesce(p_short_label, short_label),
           updated_at   = now()
     where id = p_id and user_id = v_uid
    returning * into v_row;
    if v_row.id is null then
      raise exception 'address not found or not yours';
    end if;
  end if;

  return v_row;
end;
$$;


-- ============================================================================
-- 5. restaurants_near RPC — ordered by distance (km).
-- ============================================================================
create or replace function public.restaurants_near(
  p_latitude   double precision,
  p_longitude  double precision,
  p_radius_km  double precision default 10
) returns table (
  id                   uuid,
  name                 text,
  logo_url             text,
  delivery_charge      numeric,
  is_active            boolean,
  price_per_plate      numeric,
  min_guests           int,
  delivery_min_minutes int,
  delivery_max_minutes int,
  rating               numeric,
  ratings_count        int,
  cuisines_display     text,
  hero_bg_hex          text,
  hero_emoji           text,
  tag                  text,
  is_pure_veg          boolean,
  popularity_score     int,
  latitude             double precision,
  longitude            double precision,
  address              text,
  distance_km          double precision
)
language sql
stable
security invoker
set search_path = public
as $$
  with origin as (
    select st_setsrid(st_makepoint(p_longitude, p_latitude), 4326)::geography as g
  )
  select r.id, r.name, r.logo_url, r.delivery_charge, r.is_active,
         r.price_per_plate, r.min_guests,
         r.delivery_min_minutes, r.delivery_max_minutes,
         r.rating, r.ratings_count, r.cuisines_display,
         r.hero_bg_hex, r.hero_emoji, r.tag, r.is_pure_veg,
         r.popularity_score, r.latitude, r.longitude, r.address,
         (st_distance(r.location, origin.g) / 1000.0)::double precision as distance_km
    from public.restaurants r, origin
   where r.is_active
     and r.location is not null
     and st_dwithin(r.location, origin.g, p_radius_km * 1000)
   order by r.location <-> origin.g
   limit 200;
$$;


-- ============================================================================
-- 6. (Optional seed) — set coordinates for a couple of existing restaurants
--    so the nearby RPC returns something during dev. Uncomment + adjust.
-- ============================================================================
-- update public.restaurants
--    set latitude  = 17.4239,
--        longitude = 78.4483,
--        address   = 'Banjara Hills, Hyderabad'
--  where name ilike '%Paradise%';
-- update public.restaurants
--    set latitude  = 17.4400,
--        longitude = 78.3489,
--        address   = 'Kukatpally, Hyderabad'
--  where name ilike '%Grand Trunk%';
