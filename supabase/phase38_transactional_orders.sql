-- ============================================================================
-- Phase 38 — Transactional order placement, full booking persistence,
--            status synchronization, secure customer cancel.
-- ----------------------------------------------------------------------------
-- 1. events/orders/order_items gain the columns needed to persist the WHOLE
--    booking (category, venue type, coordinates, private-property details,
--    add-on selections, setup cost, per-line portion/spice/notes) — these
--    were silently dropped before.
-- 2. place_order(): ONE server-side transaction replacing the client's four
--    sequential inserts (events → orders → lots → items) that could strand a
--    partial booking. Validates availability/publish/min-guests/capacity/
--    date/time and computes pricing AUTHORITATIVELY from DB prices +
--    charges_config (client totals are advisory only).
-- 3. cancel_my_order(): customers can cancel their own placed/confirmed
--    orders without needing a broad UPDATE policy on orders.
-- 4. Sync triggers: banquet decline cancels the customer order; banquet
--    accept confirms it; a cancelled order cancels its not-yet-picked-up
--    vendor lots; order status transitions stamp their timestamp columns.
--
-- Idempotent. No data destroyed.
-- ============================================================================

-- ── 1) Persistence columns ──────────────────────────────────────────────────

alter table public.events
  add column if not exists category_slug    text,
  add column if not exists venue_type       text,
  add column if not exists event_latitude   double precision,
  add column if not exists event_longitude  double precision,
  add column if not exists property_details jsonb,
  add column if not exists addon_selections jsonb;

do $$ begin
  alter table public.events
    add constraint events_venue_type_check
    check (venue_type is null
           or venue_type in ('banquet_hall', 'private_property'));
exception when duplicate_object then null; end $$;

alter table public.orders
  add column if not exists setup_equipment numeric(12,2) not null default 0;

alter table public.order_items
  add column if not exists portion text,
  add column if not exists spice   text,
  add column if not exists notes   text;

-- ── 2) place_order — one transaction, server-authoritative ─────────────────

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

  v_venue_type := nullif(p_event->>'venue_type', '');
  if v_venue_type is not null
     and v_venue_type not in ('banquet_hall', 'private_property') then
    raise exception 'Invalid venue type.';
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

  -- Banquet venue capacity.
  v_banquet_venue := nullif(p_event->>'banquet_venue_id', '')::uuid;
  if v_banquet_venue is not null then
    select capacity into v_capacity
    from banquet_venues where id = v_banquet_venue;
    if v_capacity is not null and v_guests > v_capacity then
      raise exception 'This venue seats up to % guests — reduce the guest count or pick another venue.',
        v_capacity;
    end if;
  end if;

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
    nullif(trim(coalesce(p_event->>'name', '')), ''),
    v_date,
    trim(p_event->>'location'),
    p_event->>'session',
    v_start,
    v_end,
    v_guests,
    nullif(p_event->>'tier_id', '')::uuid,
    v_banquet_venue,
    nullif(p_event->>'category_slug', ''),
    v_venue_type,
    (p_event->>'event_latitude')::double precision,
    (p_event->>'event_longitude')::double precision,
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

revoke all on function public.place_order(jsonb, jsonb, integer, boolean, numeric) from public;
revoke all on function public.place_order(jsonb, jsonb, integer, boolean, numeric) from anon;
grant execute on function public.place_order(jsonb, jsonb, integer, boolean, numeric) to authenticated;

-- ── 3) cancel_my_order — customer-safe cancellation ─────────────────────────

create or replace function public.cancel_my_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_status order_status;
begin
  if v_user is null then
    raise exception 'Sign in first.';
  end if;
  select order_status into v_status
  from orders where id = p_order_id and user_id = v_user;
  if v_status is null then
    raise exception 'Order not found.';
  end if;
  if v_status not in ('placed', 'confirmed') then
    raise exception 'This order can''t be cancelled anymore — it''s already %.',
      v_status;
  end if;
  update orders
     set order_status = 'cancelled'
   where id = p_order_id;  -- timestamps + lot sync handled by triggers below
end;
$$;

revoke all on function public.cancel_my_order(uuid) from public;
revoke all on function public.cancel_my_order(uuid) from anon;
grant execute on function public.cancel_my_order(uuid) to authenticated;

-- ── 4) Status synchronization ───────────────────────────────────────────────
-- (Timestamp stamping already exists: trg_orders_status from phase3.)

-- 4a) A cancelled order cascades to its vendor lots that haven't been
--     picked up yet, so kitchens stop seeing work for a dead order.
create or replace function public.orders_cancel_cascade()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.order_status = 'cancelled'
     and old.order_status is distinct from 'cancelled' then
    update order_vendor_lots
       set status = 'cancelled'
     where order_id = new.id
       and status in ('pending', 'accepted', 'preparing', 'ready_for_pickup');
  end if;
  return new;
end;
$$;

drop trigger if exists orders_cancel_cascade on public.orders;
create trigger orders_cancel_cascade
  after update on public.orders
  for each row execute function public.orders_cancel_cascade();

-- 4b) Banquet decision propagates to the customer's order: a decline cancels
--     it, an acceptance confirms a freshly-placed one.
create or replace function public.events_banquet_status_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.banquet_status is distinct from old.banquet_status then
    if new.banquet_status = 'declined' then
      update orders
         set order_status = 'cancelled'
       where event_id = new.id
         and order_status in ('placed', 'confirmed', 'preparing');
    elsif new.banquet_status = 'accepted' then
      update orders
         set order_status = 'confirmed'
       where event_id = new.id
         and order_status = 'placed';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists events_banquet_status_sync on public.events;
create trigger events_banquet_status_sync
  after update on public.events
  for each row execute function public.events_banquet_status_sync();

-- ── 5) Account deletion requests — makes the profile "Delete my account"
--       action real instead of a fake success snackbar ─────────────────────

create table if not exists public.account_deletion_requests (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  reason     text,
  created_at timestamptz not null default now(),
  unique (user_id)
);

alter table public.account_deletion_requests enable row level security;

do $$ begin
  create policy deletion_requests_own_insert on public.account_deletion_requests
    for insert with check (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy deletion_requests_own_read on public.account_deletion_requests
    for select using (auth.uid() = user_id or public.is_admin(auth.uid()));
exception when duplicate_object then null; end $$;
