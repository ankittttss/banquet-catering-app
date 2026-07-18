-- Phase 40 — banquet venue location guard.
--
-- Venues drive the customer's "restaurants near your event" sort, so an
-- ACTIVE venue must always carry a usable location. Before this, venues were
-- hand-inserted and nothing forced coordinates — a coordinate-less venue
-- silently degraded the restaurant sort back to the customer's home address.
--
-- Admin manage/insert/update policies already exist (venues_admin_write,
-- phase13/22), so this phase only adds the data guard.

-- 1. Active venues must have an address AND coordinates. Inactive (draft)
--    venues may be incomplete — they are invisible to customers anyway.
--    All 12 existing rows carry coords+address, so this validates cleanly.
alter table public.banquet_venues
  drop constraint if exists banquet_venues_active_needs_location;
alter table public.banquet_venues
  add constraint banquet_venues_active_needs_location
  check (
    not is_active
    or (
      latitude is not null
      and longitude is not null
      and address is not null
      and btrim(address) <> ''
    )
  );

-- 2. Guard rails on the coordinate values themselves (typo insurance —
--    a lat of 784.4 would otherwise pass and break distance math).
alter table public.banquet_venues
  drop constraint if exists banquet_venues_coords_range;
alter table public.banquet_venues
  add constraint banquet_venues_coords_range
  check (
    (latitude is null or (latitude between -90 and 90))
    and (longitude is null or (longitude between -180 and 180))
  );
