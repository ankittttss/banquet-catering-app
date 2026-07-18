-- Phase 42 — serviceability hardening (server-authoritative).
--
-- 1. restaurants_for_event: restaurants WITHOUT coordinates used to pass a
--    location-radius search (treated as in-radius). Now a radius search only
--    returns restaurants with real coordinates inside the radius. Zero rows
--    are affected today (every published restaurant carries coordinates —
--    phase34's publish gate requires them), so this is pure future-proofing.
--    Security audit (not copied from phase14): switched from SECURITY
--    DEFINER to INVOKER — verified safe because event_tiers has
--    tiers_public_read USING(true) and restaurants has
--    restaurants_public_read covering published rows. EXECUTE is revoked
--    from PUBLIC/anon and granted to authenticated + service_role only
--    (customer flows run post-login).
--
-- 2. place_order: previously stored event coordinates without validating
--    them and never checked restaurant serviceability, so a direct RPC
--    caller could order from any kitchen anywhere. Now the RPC itself:
--      • requires event coordinates, validated to lat -90..90 / lng
--        -180..180;
--      • requires every distinct restaurant in the cart to carry
--        coordinates;
--      • requires every restaurant to be within the 10 km service radius
--        of the event point (mirrors kServiceRadiusKm / restaurants_near);
--      • raises a clear error naming the offending restaurant.
--    Works for multi-restaurant carts; clients can no longer be bypassed.
--    It also enforces the FULL planning workflow: an active tier is
--    required; venue_type is required; banquet orders need a selected,
--    still-ACTIVE banquet venue (existence + capacity checked); private-
--    property orders need complete property details (type, address line,
--    city/pincode). No client backfilling can sidestep these.
--    place_order stays SECURITY DEFINER by design (it writes across
--    events/orders/lots/items); its grants were already authenticated-only
--    (phase38) — unchanged.
--
-- Safe to re-run: only CREATE OR REPLACE + REVOKE/GRANT.

-- ============================================================================
-- 1. restaurants_for_event — coordinate-less restaurants never pass a
--    radius search.
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
security invoker
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
      -- No search point → whole catalog (tier-filtered) as before.
      p_lat is null or p_lng is null
      -- Search point given → ONLY restaurants with real coordinates inside
      -- the radius. Unknown locations no longer masquerade as in-range.
      or (
        r.latitude is not null and r.longitude is not null
        and ST_DistanceSphere(
              ST_MakePoint(r.longitude::float8, r.latitude::float8),
              ST_MakePoint(p_lng::float8,       p_lat::float8)
            ) <= (p_radius_km * 1000)
      )
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

revoke all on function
  public.restaurants_for_event(uuid, numeric, numeric, numeric) from public;
revoke all on function
  public.restaurants_for_event(uuid, numeric, numeric, numeric) from anon;
grant execute on function
  public.restaurants_for_event(uuid, numeric, numeric, numeric)
  to authenticated, service_role;

-- ============================================================================
-- 2. place_order — event-coordinate validation + per-restaurant
--    serviceability. Body identical to phase38 except the two new blocks
--    marked "phase42".
-- ============================================================================
create or replace function public.place_order(
  p_event jsonb,
  p_items jsonb,
  p_service_boy_count integer default 1,
  p_include_service_tax boolean default true,
  p_addons_total numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_guests int;
  v_date date;
  v_start time;
  v_end time;
  v_venue_type text;
  v_banquet_venue uuid;
  v_capacity int;
  v_boys int;
  v_addons numeric;
  v_bad record;
  -- phase42: event point for the serviceability check
  v_lat double precision;
  v_lng double precision;
  -- phase42: full planning workflow enforcement
  v_tier uuid;
  v_venue_active boolean;
  -- charges config (defaults match the client fallback)
  c_banquet numeric := 0;
  c_buffet numeric := 0;
  c_boy numeric := 0;
  c_water numeric := 0;
  c_platform numeric := 0;
  c_gst_pct numeric := 5;
  c_svc_pct numeric := 5;
  -- computed money
  v_food numeric := 0;
  v_delivery numeric := 0;
  v_banquet numeric := 0;
  v_setup numeric := 0;
  v_service numeric := 0;
  v_subtotal numeric;
  v_gst numeric;
  v_service_tax numeric;
  v_total numeric;
  v_event_id uuid;
  v_order_id uuid;
  v_primary_restaurant uuid;
begin
  if v_user is null then
    raise exception 'Sign in to place an order.';
  end if;

  -- ── Validate the event payload ──
  v_guests := coalesce((p_event->>'guest_count')::int, 0);
  if v_guests < 1 or v_guests > 100000 then
    raise exception 'Guest count must be between 1 and 100000.';
  end if;

  v_date := (p_event->>'event_date')::date;
  if v_date is null then
    raise exception 'Pick an event date.';
  end if;
  if v_date < current_date then
    raise exception 'The event date can''t be in the past.';
  end if;

  v_start := (p_event->>'start_time')::time;
  v_end   := (p_event->>'end_time')::time;
  if v_start is null or v_end is null then
    raise exception 'Pick the event start and end time.';
  end if;
  if v_end <= v_start then
    raise exception 'End time must be after the start time.';
  end if;

  if coalesce(trim(p_event->>'location'), '') = '' then
    raise exception 'Add the event location.';
  end if;
  if coalesce(trim(p_event->>'session'), '') = '' then
    raise exception 'Pick a session (lunch / dinner / high tea).';
  end if;
  -- phase42: a real event has a name — the client requires one, so a blank
  -- name only ever comes from a direct RPC caller.
  if coalesce(trim(p_event->>'name'), '') = '' then
    raise exception 'Name your event before placing the order.';
  end if;

  -- phase42: the event point is REQUIRED and must be sane — it anchors the
  -- serviceability check below. Without it we can't know that any kitchen
  -- actually serves the event.
  v_lat := (p_event->>'event_latitude')::double precision;
  v_lng := (p_event->>'event_longitude')::double precision;
  if v_lat is null or v_lng is null then
    raise exception 'Confirm your event location (pick it from the address suggestions) before placing the order.';
  end if;
  if v_lat < -90 or v_lat > 90 or v_lng < -180 or v_lng > 180 then
    raise exception 'Invalid event coordinates.';
  end if;

  -- phase42: the FULL planning workflow is server-enforced, so direct RPC
  -- callers cannot bypass the app's checkout gate.
  -- Tier: required, must exist and be active.
  v_tier := nullif(p_event->>'tier_id', '')::uuid;
  if v_tier is null then
    raise exception 'Pick a package for your event before ordering.';
  end if;
  if not exists (
    select 1 from event_tiers t where t.id = v_tier and t.is_active
  ) then
    raise exception 'The selected package is no longer available — pick another.';
  end if;

  -- Venue type: required (was optional), then branch-specific rules.
  v_venue_type := nullif(p_event->>'venue_type', '');
  if v_venue_type is null then
    raise exception 'Choose where the event happens — banquet hall or private property.';
  end if;
  if v_venue_type not in ('banquet_hall', 'private_property') then
    raise exception 'Invalid venue type.';
  end if;

  v_banquet_venue := nullif(p_event->>'banquet_venue_id', '')::uuid;
  if v_venue_type = 'banquet_hall' then
    -- Banquet path: a venue must be selected, still active, and big enough.
    if v_banquet_venue is null then
      raise exception 'Pick a banquet venue for your event.';
    end if;
    select bv.capacity, bv.is_active into v_capacity, v_venue_active
      from banquet_venues bv where bv.id = v_banquet_venue;
    if not found or not v_venue_active then
      raise exception 'That banquet venue is no longer available — pick another.';
    end if;
    if v_capacity is not null and v_guests > v_capacity then
      raise exception 'This venue seats up to % guests — reduce the guest count or pick another venue.',
        v_capacity;
    end if;
  else
    -- Private-property path: a stray banquet_venue_id would wrongly route
    -- the event into a banquet operator's inbox — reject the contradiction.
    if v_banquet_venue is not null then
      raise exception 'A private-property event can''t carry a banquet venue — remove it or switch to the banquet-hall flow.';
    end if;
    -- The property details the app collects must be complete (matches
    -- PrivatePropertyDraft.isComplete: type + address line + city/pincode).
    if coalesce(trim(p_event->'property_details'->>'type'), '') = ''
       or coalesce(trim(p_event->'property_details'->>'addressLine1'), '') = ''
       or coalesce(trim(p_event->'property_details'->>'cityPincode'), '') = '' then
      raise exception 'Complete your property details (type, address, city & pincode) before ordering.';
    end if;
  end if;

  v_boys := least(greatest(coalesce(p_service_boy_count, 0), 0), 999);
  v_addons := least(greatest(coalesce(p_addons_total, 0), 0), 10000000);

  -- ── Parse the cart ──
  drop table if exists _po_items;
  create temp table _po_items on commit drop as
  select
    (e.i->>'menu_item_id')::uuid as menu_item_id,
    least(greatest(coalesce((e.i->>'qty_per_guest')::numeric, 1), 0.01), 99)
      as qty_per_guest,
    least(greatest(coalesce((e.i->>'portion_multiplier')::numeric, 1), 1.0), 2.0)
      as multiplier,
    nullif(e.i->>'portion', '') as portion,
    nullif(e.i->>'spice', '')   as spice,
    nullif(left(e.i->>'notes', 500), '') as notes,
    e.ord
  from jsonb_array_elements(p_items) with ordinality as e(i, ord);

  if not exists (select 1 from _po_items) then
    raise exception 'Your cart is empty.';
  end if;

  -- ── Validate items against the CURRENT catalog ──
  select t.menu_item_id::text as label into v_bad
  from _po_items t
  left join menu_items mi on mi.id = t.menu_item_id
  where mi.id is null or not mi.is_available or mi.deleted_at is not null
  limit 1;
  if found then
    raise exception 'Some items in your cart are no longer available. Please review your cart.';
  end if;

  select r.name as label into v_bad
  from _po_items t
  join menu_items mi on mi.id = t.menu_item_id
  join restaurants r on r.id = mi.restaurant_id
  where r.status <> 'published'
  limit 1;
  if found then
    raise exception '"%" is no longer taking orders. Please review your cart.', v_bad.label;
  end if;

  -- Restaurant minimum guest count.
  select r.name as label, r.min_guests as min_guests into v_bad
  from (select distinct mi.restaurant_id
        from _po_items t join menu_items mi on mi.id = t.menu_item_id) x
  join restaurants r on r.id = x.restaurant_id
  where r.min_guests is not null and r.min_guests > v_guests
  order by r.min_guests desc
  limit 1;
  if found then
    raise exception '"%" caters for a minimum of % guests — increase your guest count or remove its dishes.',
      v_bad.label, v_bad.min_guests;
  end if;

  -- phase42: serviceability — EVERY distinct restaurant in the cart (multi-
  -- restaurant orders included) must carry coordinates and lie within the
  -- 10 km service radius of the event point. 10 km mirrors the client's
  -- kServiceRadiusKm and the restaurants_near default. Errors name the
  -- offending restaurant so the customer knows what to remove.
  select r.name as label into v_bad
  from (select distinct mi.restaurant_id
        from _po_items t join menu_items mi on mi.id = t.menu_item_id) x
  join restaurants r on r.id = x.restaurant_id
  where r.latitude is null or r.longitude is null
  limit 1;
  if found then
    raise exception '"%" has no service location on record and can''t take event orders yet. Please remove its dishes.',
      v_bad.label;
  end if;

  select r.name as label into v_bad
  from (select distinct mi.restaurant_id
        from _po_items t join menu_items mi on mi.id = t.menu_item_id) x
  join restaurants r on r.id = x.restaurant_id
  where ST_DistanceSphere(
          ST_MakePoint(r.longitude::float8, r.latitude::float8),
          ST_MakePoint(v_lng::float8, v_lat::float8)
        ) > 10000
  limit 1;
  if found then
    raise exception '"%" is outside the 10 km service area of your event location — remove its dishes or change the event location.',
      v_bad.label;
  end if;

  -- (Banquet venue existence/active/capacity checks moved up into the
  -- planning-workflow block.)

  -- ── Authoritative pricing (DB prices + charges_config) ──
  select coalesce(sum(mi.price * t.multiplier * t.qty_per_guest), 0) * v_guests
  into v_food
  from _po_items t join menu_items mi on mi.id = t.menu_item_id;

  select coalesce(sum(d.delivery_charge), 0) into v_delivery
  from (select distinct r.id, r.delivery_charge
        from _po_items t
        join menu_items mi on mi.id = t.menu_item_id
        join restaurants r on r.id = mi.restaurant_id) d;

  select coalesce(banquet_charge, 0), coalesce(buffet_setup, 0),
         coalesce(service_boy_cost, 0), coalesce(water_bottle_cost, 0),
         coalesce(platform_fee, 0), coalesce(gst_percent, 5),
         coalesce(service_tax_percent, 5)
  into c_banquet, c_buffet, c_boy, c_water, c_platform, c_gst_pct, c_svc_pct
  from charges_config limit 1;

  if v_venue_type = 'private_property' then
    v_banquet := 0;
    v_setup := v_addons;
  else
    v_banquet := c_banquet;
    v_setup := 0;
  end if;
  v_service := c_boy * v_boys;

  v_subtotal := v_food + v_banquet + v_delivery + c_buffet + v_service
                + c_water + v_setup + c_platform;
  v_gst := v_subtotal * (c_gst_pct / 100);
  v_service_tax := case when p_include_service_tax
                        then v_subtotal * (c_svc_pct / 100) else 0 end;
  v_total := v_subtotal + v_gst + v_service_tax;

  -- ── Atomic inserts (whole function = one transaction) ──
  insert into events (
    user_id, name, event_date, location, session, start_time, end_time,
    guest_count, tier_id, banquet_venue_id,
    category_slug, venue_type, event_latitude, event_longitude,
    property_details, addon_selections
  ) values (
    v_user,
    trim(p_event->>'name'), -- guaranteed non-blank by the name check above
    v_date,
    trim(p_event->>'location'),
    p_event->>'session',
    v_start,
    v_end,
    v_guests,
    v_tier,
    v_banquet_venue,
    nullif(p_event->>'category_slug', ''),
    v_venue_type,
    v_lat,
    v_lng,
    case when p_event ? 'property_details'
         then p_event->'property_details' end,
    case when p_event ? 'addon_selections'
         then p_event->'addon_selections' end
  ) returning id into v_event_id;

  select mi.restaurant_id into v_primary_restaurant
  from _po_items t join menu_items mi on mi.id = t.menu_item_id
  order by t.ord
  limit 1;

  insert into orders (
    event_id, user_id, restaurant_id,
    food_cost, banquet_charge, delivery_charge, buffet_setup,
    service_boy_cost, service_boy_count, water_bottle_cost,
    setup_equipment, platform_fee, subtotal, gst, total,
    payment_status, order_status
  ) values (
    v_event_id, v_user, v_primary_restaurant,
    v_food, v_banquet, v_delivery, c_buffet,
    v_service, v_boys, c_water,
    v_setup, c_platform, v_subtotal,
    v_gst + v_service_tax,  -- single gst column keeps total = subtotal + gst
    v_total,
    'pending', 'placed'
  ) returning id into v_order_id;

  insert into order_vendor_lots (order_id, restaurant_id, subtotal, status)
  select v_order_id, mi.restaurant_id,
         sum(mi.price * t.multiplier * t.qty_per_guest) * v_guests,
         'pending'
  from _po_items t join menu_items mi on mi.id = t.menu_item_id
  group by mi.restaurant_id;

  insert into order_items (
    order_id, menu_item_id, qty, qty_per_guest, price_at_order,
    vendor_lot_id, portion, spice, notes
  )
  select
    v_order_id, t.menu_item_id,
    greatest(round(t.qty_per_guest)::int, 1),
    t.qty_per_guest,
    mi.price * t.multiplier,
    l.id, t.portion, t.spice, t.notes
  from _po_items t
  join menu_items mi on mi.id = t.menu_item_id
  join order_vendor_lots l
    on l.order_id = v_order_id and l.restaurant_id = mi.restaurant_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'event_id', v_event_id,
    'total', v_total
  );
end;
$$;

-- Grants unchanged from phase38 (authenticated only) — re-asserted so this
-- file stands alone if re-run.
revoke all on function
  public.place_order(jsonb, jsonb, integer, boolean, numeric) from public;
revoke all on function
  public.place_order(jsonb, jsonb, integer, boolean, numeric) from anon;
grant execute on function
  public.place_order(jsonb, jsonb, integer, boolean, numeric) to authenticated;
