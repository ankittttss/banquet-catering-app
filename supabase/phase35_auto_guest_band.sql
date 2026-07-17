-- ============================================================================
-- Phase 35 — Auto-derive the per-guest budget band from the plate price.
-- ----------------------------------------------------------------------------
-- The plan-your-event tier flow (restaurants_for_event, phase14) matches
-- restaurants by per_guest_price_min/max. Seed rows were backfilled in
-- phase14, but newly onboarded restaurants only get a price_per_plate from
-- the admin wizard — leaving the band NULL and the restaurant invisible in
-- the tier-filtered list.
--
-- Fix: whenever a restaurant is written with a plate price but no band,
-- derive it with the exact phase14 backfill formula
--   min = greatest(80% of plate price, 120)
--   max = greatest(130% of plate price, 250)
-- Implemented inside the phase34 lifecycle trigger (single writer path).
--
-- Idempotent: safe to re-run.
-- ============================================================================

create or replace function public.restaurants_before_write()
returns trigger
language plpgsql
as $$
declare
  entering_published boolean :=
    new.status = 'published'
    and (tg_op = 'INSERT' or old.status is distinct from 'published');
begin
  -- a) Publish gate — refuse to publish an incomplete restaurant. Runs only
  --    on the transition INTO 'published', so edits to already-published
  --    seed rows (which pre-date these requirements) are not blocked.
  if entering_published then
    if coalesce(trim(new.name), '') = '' then
      raise exception 'Cannot publish: restaurant name is required.';
    end if;
    if new.price_per_plate is null or new.price_per_plate <= 0 then
      raise exception 'Cannot publish "%": price per plate is required.', new.name;
    end if;
    if new.min_guests is null or new.min_guests <= 0 then
      raise exception 'Cannot publish "%": minimum guests is required.', new.name;
    end if;
    if coalesce(trim(new.address), '') = ''
       or new.latitude is null
       or new.longitude is null then
      raise exception 'Cannot publish "%": address and map location are required.', new.name;
    end if;
    if new.logo_url is null and new.cover_image_url is null then
      raise exception 'Cannot publish "%": a logo or cover image is required.', new.name;
    end if;
    if not exists (
      select 1 from public.menu_items mi
      where mi.restaurant_id = new.id
        and mi.is_available
    ) then
      raise exception 'Cannot publish "%": add at least one available menu item first.', new.name;
    end if;
  end if;

  -- b) is_active mirrors status — single source of truth. Every existing
  --    customer read path filters is_active, so nothing else changes.
  new.is_active := (new.status = 'published');

  -- c) Per-guest budget band: derive from the plate price when missing so
  --    new restaurants appear in the tier-filtered flow (phase35).
  if new.price_per_plate is not null then
    if new.per_guest_price_min is null then
      new.per_guest_price_min :=
        greatest((new.price_per_plate * 0.80)::numeric(10, 2), 120);
    end if;
    if new.per_guest_price_max is null then
      new.per_guest_price_max :=
        greatest((new.price_per_plate * 1.30)::numeric(10, 2), 250);
    end if;
  end if;

  -- d) Lifecycle timestamps.
  if entering_published then
    new.published_at := now();
  end if;
  if new.status = 'archived'
     and (tg_op = 'INSERT' or old.status is distinct from 'archived') then
    new.archived_at := now();
  end if;
  -- Restoring out of archive clears the marker ("archived_at = currently
  -- archived since"); published_at intentionally keeps the latest publish.
  if tg_op = 'UPDATE'
     and old.status = 'archived'
     and new.status <> 'archived' then
    new.archived_at := null;
  end if;

  if tg_op = 'UPDATE' then
    new.updated_at := now();
  end if;

  return new;
end;
$$;

-- Backfill any rows written between phase34 and this fix (e.g. wizard
-- drafts) that carry a plate price but no band.
update public.restaurants
   set per_guest_price_min =
         greatest((price_per_plate * 0.80)::numeric(10, 2), 120),
       per_guest_price_max =
         greatest((price_per_plate * 1.30)::numeric(10, 2), 250)
 where price_per_plate is not null
   and (per_guest_price_min is null or per_guest_price_max is null);
