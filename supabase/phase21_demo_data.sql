-- ============================================================================
-- Phase 21 — Bulk demo data (dev only).
--
-- Seeds 3 customers with 4 events + orders across 4 lifecycle states so
-- every role's inbox / board shows live content the moment you log in:
--
--   Event A — pending   (banquet1's inbox shows Accept/Decline)
--   Event B — accepted  (manager1 assigned; serviceboy1 staffed; lot preparing)
--   Event C — accepted  (manager1 assigned; serviceboy2 staffed; lot ready)
--   Event D — pending   (fresh, no accepts yet — second inbox item)
--
-- Idempotent: uses stable UUIDs for every inserted row. Re-running refreshes
-- amounts / statuses without duplicating.
--
-- PREREQUISITE: phase19_bootstrap_test_roles.sql (creates the 6 operator
-- accounts + venues) must already have run.
-- ============================================================================


-- ============================================================================
-- 1. Demo customer auth accounts (customer1/2/3@dawat.test, password dawat1234).
-- ============================================================================
insert into auth.users (
  instance_id, id, aud, role, email,
  encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at,
  confirmation_token, recovery_token,
  email_change, email_change_token_new, email_change_token_current,
  phone_change, phone_change_token,
  reauthentication_token
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  (u->>'id')::uuid,
  'authenticated', 'authenticated',
  u->>'email',
  crypt('dawat1234', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  now(), now(),
  '', '', '', '', '', '', '', ''
  from (values
    ('{"id":"44444444-0000-0000-0000-000000000001","email":"customer1@dawat.test"}'::jsonb),
    ('{"id":"44444444-0000-0000-0000-000000000002","email":"customer2@dawat.test"}'::jsonb),
    ('{"id":"44444444-0000-0000-0000-000000000003","email":"customer3@dawat.test"}'::jsonb)
  ) as t(u)
on conflict (id) do nothing;

insert into public.profiles (id, email, name, role)
values
  ('44444444-0000-0000-0000-000000000001', 'customer1@dawat.test', 'Priya Sharma',    'customer'),
  ('44444444-0000-0000-0000-000000000002', 'customer2@dawat.test', 'Rohan Mehta',     'customer'),
  ('44444444-0000-0000-0000-000000000003', 'customer3@dawat.test', 'Ananya Kapoor',   'customer')
on conflict (id) do update set
  email = excluded.email,
  name  = excluded.name,
  role  = excluded.role;


-- ============================================================================
-- 2. Helpers — pick restaurant1's kitchen + the Classic tier as anchor rows.
-- ============================================================================
-- Stash them in a temp table so the rest of the script reads cleanly.
create temp table _demo_refs as
select
  (select id from public.event_tiers where code = 'standard' limit 1)         as tier_id,
  (select restaurant_id from public.restaurant_staff
    where profile_id = '22222222-0000-0000-0000-000000000002' limit 1)         as kitchen_id,
  '33333333-0000-0000-0000-000000000001'::uuid                                 as venue_id;

-- If no tier or kitchen found, bail loudly rather than seed garbage.
do $$
declare
  v_tier    uuid;
  v_kitchen uuid;
begin
  select tier_id, kitchen_id into v_tier, v_kitchen from _demo_refs;
  if v_tier is null then
    raise exception 'Phase 21: no "standard" event tier found. Run phase14 first.';
  end if;
  if v_kitchen is null then
    raise exception 'Phase 21: no kitchen linked to restaurant1. Run phase19 first.';
  end if;
end $$;


-- ============================================================================
-- 3. Events — 4 demo events across 2 customers.
-- ============================================================================
-- Clean prior demo rows (FK-safe: cascades to orders → order_items → lots).
delete from public.events where id::text like '55555555-%';

insert into public.events
  (id, user_id, event_date, location, session, start_time, end_time,
   guest_count, tier_id, banquet_venue_id, banquet_status)
select
  (r->>'id')::uuid,
  (r->>'user_id')::uuid,
  (now() + ((r->>'days_out')::int * interval '1 day'))::date,
  r->>'location',
  r->>'session',
  (r->>'start_time')::time,
  (r->>'end_time')::time,
  (r->>'guest_count')::int,
  refs.tier_id,
  refs.venue_id,
  (r->>'banquet_status')::banquet_event_status
from _demo_refs refs, (values
  ('{"id":"55555555-0000-0000-0000-000000000001","user_id":"44444444-0000-0000-0000-000000000001","days_out":"14","location":"Dawat Grand Hall, Banjara Hills","session":"Dinner","start_time":"19:30","end_time":"23:00","guest_count":"120","banquet_status":"pending"}'::jsonb),
  ('{"id":"55555555-0000-0000-0000-000000000002","user_id":"44444444-0000-0000-0000-000000000002","days_out":"7", "location":"Dawat Grand Hall, Banjara Hills","session":"Lunch","start_time":"12:30","end_time":"15:30","guest_count":"80", "banquet_status":"accepted"}'::jsonb),
  ('{"id":"55555555-0000-0000-0000-000000000003","user_id":"44444444-0000-0000-0000-000000000003","days_out":"3", "location":"Dawat Grand Hall, Banjara Hills","session":"Dinner","start_time":"20:00","end_time":"23:30","guest_count":"60", "banquet_status":"accepted"}'::jsonb),
  ('{"id":"55555555-0000-0000-0000-000000000004","user_id":"44444444-0000-0000-0000-000000000001","days_out":"21","location":"Dawat Grand Hall, Banjara Hills","session":"Lunch","start_time":"13:00","end_time":"16:00","guest_count":"200","banquet_status":"pending"}'::jsonb)
) as t(r);


-- ============================================================================
-- 4. Orders + vendor lots.
--    Subtotals are ballpark per-guest * guest_count at Classic tier.
-- ============================================================================
delete from public.orders where id::text like '66666666-%';

insert into public.orders
  (id, event_id, user_id, restaurant_id, food_cost, banquet_charge,
   delivery_charge, buffet_setup, service_boy_cost, water_bottle_cost,
   platform_fee, subtotal, gst, total,
   payment_status, order_status)
select
  (r->>'id')::uuid,
  (r->>'event_id')::uuid,
  (r->>'user_id')::uuid,
  refs.kitchen_id,
  (r->>'food_cost')::numeric, 8000, 0, 2500, 3500, (r->>'water')::numeric,
  149,
  (r->>'subtotal')::numeric,
  round(((r->>'subtotal')::numeric * 0.05), 2),
  round(((r->>'subtotal')::numeric * 1.05), 2),
  'pending', 'placed'
from _demo_refs refs, (values
  ('{"id":"66666666-0000-0000-0000-000000000001","event_id":"55555555-0000-0000-0000-000000000001","user_id":"44444444-0000-0000-0000-000000000001","food_cost":"36000","water":"3000","subtotal":"53149"}'::jsonb),
  ('{"id":"66666666-0000-0000-0000-000000000002","event_id":"55555555-0000-0000-0000-000000000002","user_id":"44444444-0000-0000-0000-000000000002","food_cost":"24000","water":"2000","subtotal":"40149"}'::jsonb),
  ('{"id":"66666666-0000-0000-0000-000000000003","event_id":"55555555-0000-0000-0000-000000000003","user_id":"44444444-0000-0000-0000-000000000003","food_cost":"18000","water":"1500","subtotal":"33649"}'::jsonb),
  ('{"id":"66666666-0000-0000-0000-000000000004","event_id":"55555555-0000-0000-0000-000000000004","user_id":"44444444-0000-0000-0000-000000000001","food_cost":"60000","water":"5000","subtotal":"79149"}'::jsonb)
) as t(r);

-- Vendor lots — one per order, on restaurant1's kitchen.
insert into public.order_vendor_lots
  (id, order_id, restaurant_id, subtotal, status)
select
  (r->>'id')::uuid,
  (r->>'order_id')::uuid,
  refs.kitchen_id,
  (r->>'subtotal')::numeric,
  (r->>'status')::vendor_lot_status
from _demo_refs refs, (values
  ('{"id":"77777777-0000-0000-0000-000000000001","order_id":"66666666-0000-0000-0000-000000000001","subtotal":"36000","status":"pending"}'::jsonb),
  ('{"id":"77777777-0000-0000-0000-000000000002","order_id":"66666666-0000-0000-0000-000000000002","subtotal":"24000","status":"preparing"}'::jsonb),
  ('{"id":"77777777-0000-0000-0000-000000000003","order_id":"66666666-0000-0000-0000-000000000003","subtotal":"18000","status":"ready_for_pickup"}'::jsonb),
  ('{"id":"77777777-0000-0000-0000-000000000004","order_id":"66666666-0000-0000-0000-000000000004","subtotal":"60000","status":"pending"}'::jsonb)
) as t(r);

-- Order items — 3 dishes per order, stub menu_items from the kitchen.
-- qty = 1 portion per guest (billed = qty * events.guest_count at display).
insert into public.order_items
  (order_id, menu_item_id, qty, qty_per_guest, price_at_order, vendor_lot_id)
select
  o.id, mi.id, 1, 1, mi.price, lots.id
from public.orders o
  join public.order_vendor_lots lots on lots.order_id = o.id
  join public.menu_items mi on mi.restaurant_id = lots.restaurant_id
 where o.id::text like '66666666-%'
   and mi.is_available = true
 order by o.id, mi.price desc
 limit 12; -- ~3 per order * 4 orders


-- ============================================================================
-- 5. Event assignments — manager1 on Event B & C, service boys staffed.
-- ============================================================================
delete from public.event_assignments
 where event_id::text like '55555555-%';

insert into public.event_assignments
  (event_id, profile_id, role_on_event, assigned_by)
values
  -- Event B (55555555-...02): manager1 + serviceboy1
  ('55555555-0000-0000-0000-000000000002',
   '22222222-0000-0000-0000-000000000003', 'manager',     '22222222-0000-0000-0000-000000000001'),
  ('55555555-0000-0000-0000-000000000002',
   '22222222-0000-0000-0000-000000000004', 'service_boy', '22222222-0000-0000-0000-000000000003'),
  -- Event C (55555555-...03): manager1 + serviceboy2
  ('55555555-0000-0000-0000-000000000003',
   '22222222-0000-0000-0000-000000000003', 'manager',     '22222222-0000-0000-0000-000000000001'),
  ('55555555-0000-0000-0000-000000000003',
   '22222222-0000-0000-0000-000000000005', 'service_boy', '22222222-0000-0000-0000-000000000003');


-- ============================================================================
-- 6. Verify.
-- ============================================================================
-- select e.id, c.email as customer, e.banquet_status, e.guest_count,
--        count(ea.id) filter (where ea.role_on_event='service_boy') as service_boys
--   from public.events e
--   join auth.users c on c.id = e.user_id
--   left join public.event_assignments ea on ea.event_id = e.id
--  where e.id::text like '55555555-%'
--  group by e.id, c.email, e.banquet_status, e.guest_count
--  order by e.event_date;
--
-- select o.id, o.total, lots.status as lot_status
--   from public.orders o
--   join public.order_vendor_lots lots on lots.order_id = o.id
--  where o.id::text like '66666666-%'
--  order by o.created_at;
