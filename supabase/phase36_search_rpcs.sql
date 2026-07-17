-- ============================================================================
-- Phase 36 — Server-side customer search.
-- ----------------------------------------------------------------------------
-- The search screen used to filter the location-scoped home list client-side,
-- so a published restaurant outside the 10 km home radius was unfindable by
-- name, and dish search downloaded the whole 23k-item catalog to the client.
--
-- Two read-only RPCs (no schema changes):
--   search_restaurants — every PUBLISHED restaurant matching name/cuisine,
--     NO radius filter; returns distance_km so the client can label results
--     "out of range" instead of hiding them. distance_km is NULL when either
--     side lacks coordinates.
--   search_menu_items — dish search joined to its live restaurant, so results
--     always carry a real restaurant name and dead "orphan" rows disappear.
--
-- Catalog is ~1.1k restaurants / ~23k items — plain ILIKE needs no index.
-- Idempotent: safe to re-run.
-- ============================================================================

create or replace function public.search_restaurants(
  p_query text,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_limit integer default 40
)
returns table (
  id uuid,
  name text,
  logo_url text,
  delivery_charge numeric,
  is_active boolean,
  price_per_plate numeric,
  min_guests integer,
  delivery_min_minutes integer,
  delivery_max_minutes integer,
  rating numeric,
  ratings_count integer,
  cuisines_display text,
  hero_bg_hex text,
  hero_emoji text,
  tag text,
  is_pure_veg boolean,
  popularity_score integer,
  latitude double precision,
  longitude double precision,
  address text,
  distance_km double precision
)
language sql
stable
security invoker
set search_path = public
as $$
  with origin as (
    select case
      when p_latitude is null or p_longitude is null then null
      else st_setsrid(
        st_makepoint(p_longitude, p_latitude), 4326
      )::geography
    end as g
  )
  select
    r.id, r.name, r.logo_url, r.delivery_charge, r.is_active,
    r.price_per_plate, r.min_guests, r.delivery_min_minutes,
    r.delivery_max_minutes, r.rating, r.ratings_count,
    r.cuisines_display, r.hero_bg_hex, r.hero_emoji, r.tag,
    r.is_pure_veg, r.popularity_score,
    r.latitude, r.longitude, r.address,
    case
      when origin.g is null or r.location is null then null
      else (st_distance(r.location, origin.g) / 1000.0)::double precision
    end as distance_km
  from public.restaurants r
  cross join origin
  where r.is_active
    and length(trim(p_query)) >= 2
    and (
      r.name ilike '%' || trim(p_query) || '%'
      or r.cuisines_display ilike '%' || trim(p_query) || '%'
    )
  order by
    -- Name hits above cuisine-only hits, then nearest, then most popular.
    (r.name ilike '%' || trim(p_query) || '%') desc,
    case
      when origin.g is null or r.location is null then null
      else st_distance(r.location, origin.g)
    end asc nulls last,
    r.popularity_score desc,
    r.name asc
  limit greatest(coalesce(p_limit, 40), 1)
$$;

create or replace function public.search_menu_items(
  p_query text,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_limit integer default 30
)
returns table (
  id uuid,
  restaurant_id uuid,
  category_id uuid,
  name text,
  description text,
  price numeric,
  image_url text,
  is_veg boolean,
  is_available boolean,
  restaurant_name text,
  distance_km double precision
)
language sql
stable
security invoker
set search_path = public
as $$
  with origin as (
    select case
      when p_latitude is null or p_longitude is null then null
      else st_setsrid(
        st_makepoint(p_longitude, p_latitude), 4326
      )::geography
    end as g
  )
  select
    mi.id, mi.restaurant_id, mi.category_id, mi.name, mi.description,
    mi.price, mi.image_url, mi.is_veg, mi.is_available,
    r.name as restaurant_name,
    case
      when origin.g is null or r.location is null then null
      else (st_distance(r.location, origin.g) / 1000.0)::double precision
    end as distance_km
  from public.menu_items mi
  join public.restaurants r
    on r.id = mi.restaurant_id
   and r.is_active                -- dishes of hidden restaurants never surface
  cross join origin
  where mi.is_available
    and length(trim(p_query)) >= 2
    and (
      mi.name ilike '%' || trim(p_query) || '%'
      or mi.description ilike '%' || trim(p_query) || '%'
    )
  order by
    (mi.name ilike '%' || trim(p_query) || '%') desc,
    case
      when origin.g is null or r.location is null then null
      else st_distance(r.location, origin.g)
    end asc nulls last,
    mi.name asc
  limit greatest(coalesce(p_limit, 30), 1)
$$;
