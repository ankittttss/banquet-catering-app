-- Phase 41 — location-based banquet venue discovery + RLS tightening.
--
-- The customer venue picker used to show EVERY active venue nationwide,
-- ordered by name — a Delhi customer saw Hyderabad halls. This phase mirrors
-- the restaurants geo stack (phase 6) for banquet_venues: a generated
-- geography column, a GiST index, and a `banquet_venues_near` RPC with a
-- hard server-side radius clamp.
--
-- It also fixes an RLS hole: `venues_public_read` was USING(true), so any
-- user could read INACTIVE venues straight off the table even though the
-- app-level queries filtered them.

-- ============================================================================
-- 1. Generated geography column + spatial index (mirrors restaurants).
--    Auto-computed from latitude/longitude — no backfill, no sync trigger.
-- ============================================================================
alter table public.banquet_venues
  add column if not exists location geography(Point, 4326)
    generated always as (
      case
        when latitude is not null and longitude is not null
          then st_setsrid(
                 st_makepoint(longitude::float8, latitude::float8),
                 4326
               )::geography
        else null
      end
    ) stored;

create index if not exists idx_banquet_venues_location
  on public.banquet_venues using gist(location);

-- ============================================================================
-- 2. RLS: public read becomes ACTIVE-ONLY.
--    Policies are permissive (OR-combined), so owners still see their own
--    inactive venues via venues_owner_rw and admins see everything via
--    venues_admin_write — no conflicts, just a wider union for those roles.
-- ============================================================================
-- Drop BOTH the legacy policy and any prior copy of the replacement so the
-- migration is safely re-runnable (create policy has no "if not exists").
drop policy if exists venues_public_read on public.banquet_venues;
drop policy if exists venues_public_read_active on public.banquet_venues;
create policy venues_public_read_active on public.banquet_venues
  for select
  using (is_active);

-- ============================================================================
-- 3. banquet_venues_near(lat, lng, radius_km, min_capacity)
--    • validates coordinates (hard error on garbage)
--    • clamps radius server-side to 1..100 km — no nationwide sweeps
--    • active + has-coordinates only
--    • hides venues whose KNOWN capacity is below the guest count;
--      unknown-capacity venues stay visible. NOTE: the tap-time check and
--      place_order's capacity check also only protect venues with a KNOWN
--      capacity — a null-capacity venue is never blocked anywhere.
--    • nearest-first, distance_km returned for display
--    SECURITY INVOKER: row visibility still passes through RLS.
-- ============================================================================
create or replace function public.banquet_venues_near(
  p_lat          numeric,
  p_lng          numeric,
  p_radius_km    numeric default 50,
  p_min_capacity int     default null
)
returns table (
  id               uuid,
  owner_profile_id uuid,
  name             text,
  address          text,
  latitude         numeric,
  longitude        numeric,
  capacity         int,
  is_active        boolean,
  distance_km      numeric
)
language plpgsql
security invoker
stable
as $$
declare
  v_radius numeric;
  v_origin geography;
begin
  if p_lat is null or p_lng is null
     or p_lat < -90 or p_lat > 90
     or p_lng < -180 or p_lng > 180 then
    raise exception
      'banquet_venues_near: invalid coordinates (%, %)', p_lat, p_lng;
  end if;

  v_radius := least(greatest(coalesce(p_radius_km, 50), 1), 100);
  v_origin := st_setsrid(
                st_makepoint(p_lng::float8, p_lat::float8), 4326
              )::geography;

  return query
  select v.id,
         v.owner_profile_id,
         v.name,
         v.address,
         v.latitude,
         v.longitude,
         v.capacity,
         v.is_active,
         (st_distance(v.location, v_origin) / 1000.0)::numeric as distance_km
    from public.banquet_venues v
   where v.is_active
     and v.location is not null
     and (
       p_min_capacity is null
       or v.capacity is null
       or v.capacity >= p_min_capacity
     )
     and st_dwithin(v.location, v_origin, v_radius * 1000)
   order by v.location <-> v_origin;
end;
$$;

-- Execution: app clients only. The default PUBLIC grant is revoked so the
-- function can't be probed anonymously (the picker runs post-login).
revoke all on function
  public.banquet_venues_near(numeric, numeric, numeric, int) from public;
revoke all on function
  public.banquet_venues_near(numeric, numeric, numeric, int) from anon;
grant execute on function
  public.banquet_venues_near(numeric, numeric, numeric, int)
  to authenticated, service_role;
