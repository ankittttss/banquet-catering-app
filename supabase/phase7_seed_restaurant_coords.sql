-- ============================================================================
-- Phase 7 — seed restaurants with random Hyderabad coordinates.
--
-- Assigns a lat/lng + address to every active restaurant that doesn't yet
-- have coordinates, picked from a list of well-known Hyderabad localities.
-- This lets you see the "restaurants near my address" behavior actually
-- change as you switch addresses in the app.
--
-- Run once in the Supabase SQL Editor. Safe to re-run (only touches rows
-- where latitude is still NULL).
-- ============================================================================

with localities(loc_name, loc_lat, loc_lng) as (
  values
    ('Banjara Hills, Hyderabad',      17.4139, 78.4520),
    ('Jubilee Hills, Hyderabad',      17.4325, 78.4073),
    ('Gachibowli, Hyderabad',         17.4401, 78.3489),
    ('Hitech City, Hyderabad',        17.4435, 78.3772),
    ('Kukatpally, Hyderabad',         17.4948, 78.4001),
    ('Madhapur, Hyderabad',           17.4483, 78.3915),
    ('Secunderabad, Hyderabad',       17.4399, 78.4983),
    ('Ameerpet, Hyderabad',           17.4374, 78.4487),
    ('Begumpet, Hyderabad',           17.4459, 78.4662),
    ('Kondapur, Hyderabad',           17.4611, 78.3640),
    ('Miyapur, Hyderabad',            17.4960, 78.3580),
    ('Mehdipatnam, Hyderabad',        17.3963, 78.4394),
    ('Charminar, Hyderabad',          17.3616, 78.4747),
    ('Dilsukhnagar, Hyderabad',       17.3687, 78.5243),
    ('LB Nagar, Hyderabad',           17.3495, 78.5487),
    ('Tarnaka, Hyderabad',            17.4253, 78.5350)
),
to_update as (
  -- Give every coord-less restaurant a row_number matched against a locality.
  select r.id,
         row_number() over (order by r.name) as rn,
         (select count(*) from localities) as n_locs
    from public.restaurants r
   where r.latitude is null
     and r.is_active
),
picks as (
  -- Round-robin pair each restaurant with one locality.
  select u.id,
         l.loc_name,
         l.loc_lat,
         l.loc_lng
    from to_update u
    join localities l
      on l.loc_name = (
           select loc_name from localities
            order by loc_name
            offset ((u.rn - 1) % u.n_locs)
            limit 1
         )
)
update public.restaurants r
   set latitude  = p.loc_lat,
       longitude = p.loc_lng,
       address   = p.loc_name
  from picks p
 where r.id = p.id;


-- Verify
select name, address, latitude, longitude
  from public.restaurants
 order by name;
