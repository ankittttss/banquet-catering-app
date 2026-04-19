-- ============================================================================
-- Phase 10 — Mock drivers + automatic dispatch on order placement.
--
--   • Adds profiles.latitude / longitude for driver location (PostGIS-native
--     distance lookups continue to work via a generated geography column).
--   • Seeds 10 mock delivery partners around Hyderabad with varied ratings,
--     vehicle types, and online states so the admin screen has something
--     to show immediately.
--   • Installs an `on_order_insert` trigger: when an order is created, a
--     `deliveries` row is auto-inserted with status='offered' so every
--     online driver sees the offer in their feed. Admins can still override
--     by manually assigning via the admin orders screen.
--
-- Safe to re-run (idempotent). Re-running refreshes mock driver state.
-- ============================================================================


-- ============================================================================
-- 1. Driver location columns.
-- ============================================================================
alter table public.profiles
  add column if not exists latitude  numeric(9,6),
  add column if not exists longitude numeric(9,6);


-- ============================================================================
-- 2. Seed mock auth.users + profile rows.
--
-- We insert directly into auth.users with stable UUIDs so re-running this
-- migration re-seeds the same drivers (upsert semantics). Email is a
-- synthetic @dawat.mock domain to make them easy to clean up later.
-- ============================================================================

-- Clean any prior mock drivers before re-seeding (safe if they don't exist).
delete from public.profiles
 where email like 'driver-mock-%@dawat.mock';
delete from auth.users
 where email like 'driver-mock-%@dawat.mock';

-- Insert mock auth.users.
-- Password is "dawat1234" for every mock driver (bcrypt hashed).
-- All text "token" columns are set to '' (not NULL) because GoTrue's login
-- flow throws "Database error querying schema" when it sees NULL there.
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
  (d->>'id')::uuid,
  'authenticated', 'authenticated',
  'driver-mock-' || (d->>'slug') || '@dawat.mock',
  crypt('dawat1234', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  now(), now(),
  '', '', '', '', '', '', '', ''
  from (
    values
      ('{"id":"11111111-0000-0000-0000-000000000001","slug":"rk01","name":"Ramesh Kumar",   "phone":"+919900000001","vehicle":"Bike",   "vehicle_number":"TS 09 AB 1234","lat":17.4350,"lng":78.3900,"rating":4.8,"deliveries":324,"online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000002","slug":"sp02","name":"Suresh Patel",   "phone":"+919900000002","vehicle":"Scooter","vehicle_number":"TS 08 CD 5678","lat":17.4474,"lng":78.3722,"rating":4.6,"deliveries":201,"online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000003","slug":"mr03","name":"Mohan Rao",      "phone":"+919900000003","vehicle":"Bike",   "vehicle_number":"TS 09 EF 9012","lat":17.4256,"lng":78.4438,"rating":4.9,"deliveries":512,"online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000004","slug":"pj04","name":"Priya Joshi",    "phone":"+919900000004","vehicle":"Scooter","vehicle_number":"TS 10 GH 3456","lat":17.4012,"lng":78.4872,"rating":4.7,"deliveries":145,"online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000005","slug":"ag05","name":"Arjun Gupta",    "phone":"+919900000005","vehicle":"Bike",   "vehicle_number":"TS 11 IJ 7890","lat":17.4840,"lng":78.4080,"rating":4.5,"deliveries":87, "online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000006","slug":"ks06","name":"Karthik Shetty", "phone":"+919900000006","vehicle":"Bicycle","vehicle_number":"",              "lat":17.3850,"lng":78.4867,"rating":4.4,"deliveries":42, "online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000007","slug":"nv07","name":"Naveen Verma",   "phone":"+919900000007","vehicle":"Bike",   "vehicle_number":"TS 12 KL 2468","lat":17.4165,"lng":78.4089,"rating":4.6,"deliveries":178,"online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000008","slug":"dk08","name":"Deepak Khan",    "phone":"+919900000008","vehicle":"Scooter","vehicle_number":"TS 13 MN 1357","lat":17.4565,"lng":78.4770,"rating":4.3,"deliveries":66, "online":false}'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000009","slug":"vm09","name":"Vikram Mehta",   "phone":"+919900000009","vehicle":"Bike",   "vehicle_number":"TS 14 OP 9753","lat":17.4930,"lng":78.3910,"rating":4.9,"deliveries":602,"online":false}'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000010","slug":"sy10","name":"Sanjay Yadav",   "phone":"+919900000010","vehicle":"Bike",   "vehicle_number":"TS 15 QR 8642","lat":17.3712,"lng":78.4520,"rating":4.2,"deliveries":33, "online":true }'::jsonb)
  ) as t(d)
on conflict (id) do nothing;

-- Insert/refresh profile rows.
insert into public.profiles (
  id, role, name, email, phone, vehicle, vehicle_number,
  rating, total_deliveries, is_online, latitude, longitude, avatar_hex
)
select
  (d->>'id')::uuid,
  'delivery',
  d->>'name',
  'driver-mock-' || (d->>'slug') || '@dawat.mock',
  d->>'phone',
  d->>'vehicle',
  d->>'vehicle_number',
  (d->>'rating')::numeric,
  (d->>'deliveries')::int,
  (d->>'online')::boolean,
  (d->>'lat')::numeric,
  (d->>'lng')::numeric,
  '#' || substr(md5(d->>'slug'), 1, 6)
  from (
    values
      ('{"id":"11111111-0000-0000-0000-000000000001","slug":"rk01","name":"Ramesh Kumar",   "phone":"+919900000001","vehicle":"Bike",   "vehicle_number":"TS 09 AB 1234","lat":17.4350,"lng":78.3900,"rating":4.8,"deliveries":324,"online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000002","slug":"sp02","name":"Suresh Patel",   "phone":"+919900000002","vehicle":"Scooter","vehicle_number":"TS 08 CD 5678","lat":17.4474,"lng":78.3722,"rating":4.6,"deliveries":201,"online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000003","slug":"mr03","name":"Mohan Rao",      "phone":"+919900000003","vehicle":"Bike",   "vehicle_number":"TS 09 EF 9012","lat":17.4256,"lng":78.4438,"rating":4.9,"deliveries":512,"online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000004","slug":"pj04","name":"Priya Joshi",    "phone":"+919900000004","vehicle":"Scooter","vehicle_number":"TS 10 GH 3456","lat":17.4012,"lng":78.4872,"rating":4.7,"deliveries":145,"online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000005","slug":"ag05","name":"Arjun Gupta",    "phone":"+919900000005","vehicle":"Bike",   "vehicle_number":"TS 11 IJ 7890","lat":17.4840,"lng":78.4080,"rating":4.5,"deliveries":87, "online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000006","slug":"ks06","name":"Karthik Shetty", "phone":"+919900000006","vehicle":"Bicycle","vehicle_number":"",              "lat":17.3850,"lng":78.4867,"rating":4.4,"deliveries":42, "online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000007","slug":"nv07","name":"Naveen Verma",   "phone":"+919900000007","vehicle":"Bike",   "vehicle_number":"TS 12 KL 2468","lat":17.4165,"lng":78.4089,"rating":4.6,"deliveries":178,"online":true }'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000008","slug":"dk08","name":"Deepak Khan",    "phone":"+919900000008","vehicle":"Scooter","vehicle_number":"TS 13 MN 1357","lat":17.4565,"lng":78.4770,"rating":4.3,"deliveries":66, "online":false}'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000009","slug":"vm09","name":"Vikram Mehta",   "phone":"+919900000009","vehicle":"Bike",   "vehicle_number":"TS 14 OP 9753","lat":17.4930,"lng":78.3910,"rating":4.9,"deliveries":602,"online":false}'::jsonb),
      ('{"id":"11111111-0000-0000-0000-000000000010","slug":"sy10","name":"Sanjay Yadav",   "phone":"+919900000010","vehicle":"Bike",   "vehicle_number":"TS 15 QR 8642","lat":17.3712,"lng":78.4520,"rating":4.2,"deliveries":33, "online":true }'::jsonb)
  ) as t(d)
on conflict (id) do update set
  role            = excluded.role,
  name            = excluded.name,
  phone           = excluded.phone,
  vehicle         = excluded.vehicle,
  vehicle_number  = excluded.vehicle_number,
  rating          = excluded.rating,
  total_deliveries= excluded.total_deliveries,
  is_online       = excluded.is_online,
  latitude        = excluded.latitude,
  longitude       = excluded.longitude,
  avatar_hex      = excluded.avatar_hex;


-- ============================================================================
-- 3. Auto-dispatch trigger: on every new order, insert a `deliveries` row
--    with status='offered'. Online delivery partners see the offer through
--    the existing `streamOffers()` feed — first driver to accept wins.
--
-- Dispatch data (addresses, OTP, etc.) is synthesized here since the catering
-- flow doesn't carry a proper pickup address on orders. These can be refined
-- later from the event/restaurant rows.
-- ============================================================================
create or replace function public.auto_dispatch_on_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_restaurant record;
  v_event      record;
  v_otp        text;
  v_item_count int;
begin
  -- Skip if a dispatch already exists for this order (idempotent re-run).
  if exists (select 1 from public.deliveries where order_id = new.id) then
    return new;
  end if;

  select name, address, latitude, longitude
    into v_restaurant
    from public.restaurants
   where id = new.restaurant_id;

  select location, guest_count, event_date, session
    into v_event
    from public.events
   where id = new.event_id;

  v_otp := lpad((floor(random() * 10000))::text, 4, '0');

  select count(*) into v_item_count
    from public.order_items
   where order_id = new.id;

  insert into public.deliveries (
    order_id, driver_id, status,
    pickup_address, drop_address,
    distance_km, earning_amount,
    item_count, restaurant_name,
    customer_name, customer_phone,
    event_label, guest_count,
    delivery_otp, eta_minutes,
    created_by
  ) values (
    new.id, null, 'offered',
    coalesce(v_restaurant.address, v_restaurant.name, 'Restaurant pickup'),
    coalesce(v_event.location, 'Customer address'),
    4.5, -- TODO: compute from PostGIS once addresses carry lat/lng
    85,
    coalesce(v_item_count, 0),
    coalesce(v_restaurant.name, 'Kitchen'),
    'Customer',
    '',
    coalesce('🎉 ' || v_event.session, '🎉 Event'),
    coalesce(v_event.guest_count, 0),
    v_otp,
    18,
    new.user_id
  );

  return new;
end $$;

drop trigger if exists trg_orders_auto_dispatch on public.orders;
create trigger trg_orders_auto_dispatch
after insert on public.orders
for each row execute function public.auto_dispatch_on_order();


-- ============================================================================
-- 4. Realtime publication — every table the Flutter app streams must be in
--    `supabase_realtime` or the subscription times out on the client.
-- ============================================================================
do $$
begin
  alter publication supabase_realtime add table public.orders;
exception when duplicate_object then null; end $$;

do $$
begin
  alter publication supabase_realtime add table public.deliveries;
exception when duplicate_object then null; end $$;

do $$
begin
  alter publication supabase_realtime add table public.profiles;
exception when duplicate_object then null; end $$;


-- ============================================================================
-- 5. Verify.
-- ============================================================================
-- select name, is_online, latitude, longitude, rating
--   from public.profiles
--  where role = 'delivery'
--  order by is_online desc, rating desc;
--
-- select id, order_id, status, restaurant_name, drop_address, offered_at
--   from public.deliveries
--  order by offered_at desc
--  limit 10;
