-- ============================================================================
-- Phase 19 — Create + bootstrap test role accounts.
--
-- Creates 6 test users directly in auth.users (same pattern as Phase 10 mock
-- drivers), promotes each to its role, wires the manager→service-boy tree,
-- creates a demo banquet venue, links a restaurant staff row, and seeds
-- equipment inventory.
--
-- Password for every account: dawat1234
--
-- Safe to re-run (idempotent — uses stable UUIDs + upsert semantics).
-- ============================================================================


-- ============================================================================
-- 1. Create the 6 test auth.users.
--    Uses stable UUIDs so re-running updates instead of duplicating.
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
  from (
    values
      ('{"id":"22222222-0000-0000-0000-000000000001","email":"banquet1@dawat.test"    }'::jsonb),
      ('{"id":"22222222-0000-0000-0000-000000000002","email":"restaurant1@dawat.test" }'::jsonb),
      ('{"id":"22222222-0000-0000-0000-000000000003","email":"manager1@dawat.test"    }'::jsonb),
      ('{"id":"22222222-0000-0000-0000-000000000004","email":"serviceboy1@dawat.test" }'::jsonb),
      ('{"id":"22222222-0000-0000-0000-000000000005","email":"serviceboy2@dawat.test" }'::jsonb),
      ('{"id":"22222222-0000-0000-0000-000000000006","email":"admin1@dawat.test"      }'::jsonb)
  ) as t(u)
on conflict (id) do nothing;


-- ============================================================================
-- 2. Ensure a profile row exists for each (handle_new_user trigger normally
--    does this; we insert defensively in case the trigger raced or is off).
-- ============================================================================
insert into public.profiles (id, email)
select (u->>'id')::uuid, u->>'email'
  from (
    values
      ('{"id":"22222222-0000-0000-0000-000000000001","email":"banquet1@dawat.test"    }'::jsonb),
      ('{"id":"22222222-0000-0000-0000-000000000002","email":"restaurant1@dawat.test" }'::jsonb),
      ('{"id":"22222222-0000-0000-0000-000000000003","email":"manager1@dawat.test"    }'::jsonb),
      ('{"id":"22222222-0000-0000-0000-000000000004","email":"serviceboy1@dawat.test" }'::jsonb),
      ('{"id":"22222222-0000-0000-0000-000000000005","email":"serviceboy2@dawat.test" }'::jsonb),
      ('{"id":"22222222-0000-0000-0000-000000000006","email":"admin1@dawat.test"      }'::jsonb)
  ) as t(u)
on conflict (id) do nothing;


-- ============================================================================
-- 3. Promote roles.
-- ============================================================================
update public.profiles set role = 'banquet',     name = 'Banquet Operator'
 where id = '22222222-0000-0000-0000-000000000001';

update public.profiles set role = 'restaurant',  name = 'Restaurant Manager'
 where id = '22222222-0000-0000-0000-000000000002';

update public.profiles set role = 'manager',     name = 'Event Manager One'
 where id = '22222222-0000-0000-0000-000000000003';

update public.profiles set role = 'service_boy', name = 'Service Boy One'
 where id = '22222222-0000-0000-0000-000000000004';

update public.profiles set role = 'service_boy', name = 'Service Boy Two'
 where id = '22222222-0000-0000-0000-000000000005';

update public.profiles set role = 'admin',       name = 'Admin One'
 where id = '22222222-0000-0000-0000-000000000006';


-- ============================================================================
-- 4. Wire service boys → manager.
-- ============================================================================
update public.profiles
   set reports_to_manager_id = '22222222-0000-0000-0000-000000000003'
 where id in (
   '22222222-0000-0000-0000-000000000004',
   '22222222-0000-0000-0000-000000000005'
 );


-- ============================================================================
-- 5. Banquet venue catalog.
--    The first venue ("Dawat Grand Hall") is owned by banquet1 and is the
--    one the demo flow routes bookings to. The rest are public listings so
--    the customer venue picker has real choices — all owned by banquet1 for
--    the MVP; a real deploy will have separate banquet accounts per venue.
-- ============================================================================
insert into public.banquet_venues
  (id, owner_profile_id, name, address, latitude, longitude, capacity)
values
  ('33333333-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001',
   'Dawat Grand Hall',         'Road No. 12, Banjara Hills, Hyderabad',    17.4256, 78.4438, 400),
  ('33333333-0000-0000-0000-000000000002', '22222222-0000-0000-0000-000000000001',
   'Taj Krishna Ballroom',     'Road No. 1, Banjara Hills, Hyderabad',     17.4146, 78.4471, 600),
  ('33333333-0000-0000-0000-000000000003', '22222222-0000-0000-0000-000000000001',
   'Novotel Convention',       'HITEC City, Madhapur, Hyderabad',          17.4474, 78.3722, 900),
  ('33333333-0000-0000-0000-000000000004', '22222222-0000-0000-0000-000000000001',
   'Marigold Pavilion',        'Greenlands, Begumpet, Hyderabad',          17.4375, 78.4580, 300),
  ('33333333-0000-0000-0000-000000000005', '22222222-0000-0000-0000-000000000001',
   'Sarovar Portico Gardens',  'Jubilee Hills, Hyderabad',                 17.4325, 78.4068, 250),
  ('33333333-0000-0000-0000-000000000006', '22222222-0000-0000-0000-000000000001',
   'Kohinoor Palace',          'Lakdikapul, Hyderabad',                    17.4015, 78.4624,1200),
  ('33333333-0000-0000-0000-000000000007', '22222222-0000-0000-0000-000000000001',
   'The Park Convention',      'Somajiguda, Hyderabad',                    17.4213, 78.4475, 500),
  ('33333333-0000-0000-0000-000000000008', '22222222-0000-0000-0000-000000000001',
   'Minerva Grand Lawns',      'Secunderabad, Hyderabad',                  17.4399, 78.4983, 800),
  ('33333333-0000-0000-0000-000000000009', '22222222-0000-0000-0000-000000000001',
   'Daspalla Celebrations',    'Road No. 36, Jubilee Hills, Hyderabad',    17.4256, 78.4096, 450),
  ('33333333-0000-0000-0000-00000000000a', '22222222-0000-0000-0000-000000000001',
   'Heritage Hall Hyderguda',  'Hyderguda, Hyderabad',                     17.3980, 78.4739, 350),
  ('33333333-0000-0000-0000-00000000000b', '22222222-0000-0000-0000-000000000001',
   'Sandhya Function Hall',    'Kukatpally, Hyderabad',                    17.4840, 78.4080, 700),
  ('33333333-0000-0000-0000-00000000000c', '22222222-0000-0000-0000-000000000001',
   'Vivanta Gardens',          'Gachibowli, Hyderabad',                    17.4474, 78.3489, 550)
on conflict (id) do update set
  owner_profile_id = excluded.owner_profile_id,
  name             = excluded.name,
  address          = excluded.address,
  latitude         = excluded.latitude,
  longitude        = excluded.longitude,
  capacity         = excluded.capacity;


-- ============================================================================
-- 6. Link restaurant1 as staff on the first active kitchen.
-- ============================================================================
insert into public.restaurant_staff (restaurant_id, profile_id)
select r.id, '22222222-0000-0000-0000-000000000002'
  from public.restaurants r
 where r.is_active = true
   and not exists (
     select 1 from public.restaurant_staff rs
      where rs.restaurant_id = r.id
        and rs.profile_id    = '22222222-0000-0000-0000-000000000002'
   )
 order by r.created_at asc
 limit 1;


-- ============================================================================
-- 7. Seed inventory on the demo venue.
-- ============================================================================
insert into public.banquet_inventory
  (venue_id, item_type, label, unit_price, per_guest, sort_order)
values
  ('33333333-0000-0000-0000-000000000001', 'water_bottle',    'Bottled water',         25,   true,  1),
  ('33333333-0000-0000-0000-000000000001', 'setup_basic',     'Basic banquet setup', 2500,   false, 2),
  ('33333333-0000-0000-0000-000000000001', 'service_premium', 'Premium service staff', 150, true,  3)
on conflict (venue_id, item_type) do update set
  label      = excluded.label,
  unit_price = excluded.unit_price,
  per_guest  = excluded.per_guest,
  sort_order = excluded.sort_order;


-- ============================================================================
-- 8. Verify. Uncomment to run after the migration.
-- ============================================================================
-- select u.email, p.role, p.name, p.reports_to_manager_id
--   from auth.users u
--   join public.profiles p on p.id = u.id
--  where u.email like '%@dawat.test'
--  order by u.email;
--
-- select v.name, v.capacity, u.email as owner
--   from public.banquet_venues v
--   join auth.users u on u.id = v.owner_profile_id
--  where v.id = '33333333-0000-0000-0000-000000000001';
--
-- select r.name as kitchen, u.email as staff
--   from public.restaurant_staff rs
--   join public.restaurants r on r.id = rs.restaurant_id
--   join auth.users       u on u.id = rs.profile_id
--  where u.email = 'restaurant1@dawat.test';
--
-- select label, unit_price, per_guest
--   from public.banquet_inventory
--  where venue_id = '33333333-0000-0000-0000-000000000001';
