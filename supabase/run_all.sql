-- ============================================================================
--  Dawat — Single consolidated migration.
--  Paste the whole file into Supabase SQL Editor and click "Run".
--  Idempotent — safe to re-run.
--
--  Bundles, in order:
--    1. addresses_migration.sql  (saved addresses + atomic RPCs)
--    2. seed_more_restaurants.sql (3 new restaurants + logos + menu items)
--    3. menu_images.sql           (Unsplash image_url on every item)
-- ============================================================================


-- ============================================================================
-- 1. ADDRESSES
-- ============================================================================

create table if not exists public.user_addresses (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  label       text not null check (label in ('Home','Work','Other')),
  full_address text not null check (char_length(full_address) between 3 and 500),
  is_default  boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists idx_addresses_user on public.user_addresses(user_id);

-- Only one default address per user.
create unique index if not exists ux_addresses_one_default
  on public.user_addresses(user_id) where is_default;

alter table public.user_addresses enable row level security;

drop policy if exists "addresses_owner_rw"   on public.user_addresses;
drop policy if exists "addresses_admin_read" on public.user_addresses;

create policy "addresses_owner_rw"
  on public.user_addresses for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "addresses_admin_read"
  on public.user_addresses for select
  using (public.is_admin(auth.uid()));

-- Atomic "set this address as default" — flips the default in a single txn.
create or replace function public.set_default_address(p_id uuid)
returns public.user_addresses
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.user_addresses;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1 from public.user_addresses
     where id = p_id and user_id = v_uid
  ) then
    raise exception 'address not found or not yours';
  end if;

  update public.user_addresses
     set is_default = false, updated_at = now()
   where user_id = v_uid and is_default and id <> p_id;

  update public.user_addresses
     set is_default = true, updated_at = now()
   where id = p_id
  returning * into v_row;

  return v_row;
end;
$$;

-- Atomic upsert: supports create + update, respects single-default invariant.
create or replace function public.upsert_address(
  p_id          uuid,
  p_label       text,
  p_address     text,
  p_is_default  boolean
) returns public.user_addresses
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.user_addresses;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_is_default then
    update public.user_addresses
       set is_default = false, updated_at = now()
     where user_id = v_uid and is_default
       and (p_id is null or id <> p_id);
  end if;

  if p_id is null then
    insert into public.user_addresses (user_id, label, full_address, is_default)
    values (v_uid, p_label, p_address, coalesce(p_is_default, false))
    returning * into v_row;
  else
    update public.user_addresses
       set label = p_label,
           full_address = p_address,
           is_default = coalesce(p_is_default, is_default),
           updated_at = now()
     where id = p_id and user_id = v_uid
    returning * into v_row;
    if v_row.id is null then
      raise exception 'address not found or not yours';
    end if;
  end if;

  return v_row;
end;
$$;


-- ============================================================================
-- 2. RESTAURANT LOGOS + 3 MORE RESTAURANTS WITH MENU ITEMS
-- ============================================================================

update public.restaurants set logo_url =
  'https://images.unsplash.com/photo-1546241072-48010ad2862c?w=400&q=80&auto=format&fit=crop'
  where name = 'Spice Route Catering';
update public.restaurants set logo_url =
  'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80&auto=format&fit=crop'
  where name = 'Royal Banquet Kitchen';
update public.restaurants set logo_url =
  'https://images.unsplash.com/photo-1595329083003-47e40ec25e05?w=400&q=80&auto=format&fit=crop'
  where name = 'Coastal Kitchen';

insert into public.restaurants (name, logo_url, delivery_charge, is_active)
select 'Maharaj Rasoi',
       'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80&auto=format&fit=crop',
       1300, true
  where not exists (select 1 from public.restaurants where name = 'Maharaj Rasoi');

insert into public.restaurants (name, logo_url, delivery_charge, is_active)
select 'Delhi Darbar Catering',
       'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=400&q=80&auto=format&fit=crop',
       1500, true
  where not exists (select 1 from public.restaurants where name = 'Delhi Darbar Catering');

insert into public.restaurants (name, logo_url, delivery_charge, is_active)
select 'Sattvik Events',
       'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=400&q=80&auto=format&fit=crop',
       1100, true
  where not exists (select 1 from public.restaurants where name = 'Sattvik Events');

with r as (select id, name from public.restaurants),
     c as (select id, name from public.menu_categories)
insert into public.menu_items
  (restaurant_id, category_id, name, description, price, is_veg, is_available,
   image_url)
select r.id, c.id, v.name, v.description, v.price, v.is_veg, true, v.img
from (values
  ('Maharaj Rasoi', 'Welcome Drinks', 'Badam Milk',
   'Saffron-almond cold milk', 120, true,
   'https://images.unsplash.com/photo-1546171753-97d7676e4602?w=600&q=80&auto=format&fit=crop'),
  ('Maharaj Rasoi', 'Main Course', 'Rajasthani Thali',
   'Dal bati choorma with 4 sides', 380, true,
   'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600&q=80&auto=format&fit=crop'),
  ('Maharaj Rasoi', 'Desserts', 'Mohan Thal',
   'Besan ghee fudge with pistachios', 130, true,
   'https://images.unsplash.com/photo-1601303516361-77e7e2d77eec?w=600&q=80&auto=format&fit=crop'),

  ('Delhi Darbar Catering', 'Starters', 'Chicken Tikka',
   'Classic marinated chicken, tandoor-grilled', 280, false,
   'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80&auto=format&fit=crop'),
  ('Delhi Darbar Catering', 'Main Course', 'Dal Darbari',
   'Rich black dal, overnight cooked', 210, true,
   'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600&q=80&auto=format&fit=crop'),
  ('Delhi Darbar Catering', 'Main Course', 'Kadhai Mutton',
   'Spiced mutton in iron wok', 340, false,
   'https://images.unsplash.com/photo-1574484284002-952d92456975?w=600&q=80&auto=format&fit=crop'),
  ('Delhi Darbar Catering', 'Desserts', 'Kulfi Falooda',
   'Saffron kulfi with rose falooda', 130, true,
   'https://images.unsplash.com/photo-1589249137304-08b68dc4b019?w=600&q=80&auto=format&fit=crop'),

  ('Sattvik Events', 'Starters', 'Dahi Kebab',
   'Hung-curd patties, chilli-mint chutney', 200, true,
   'https://images.unsplash.com/photo-1625944525903-f58dfa6cf4db?w=600&q=80&auto=format&fit=crop'),
  ('Sattvik Events', 'Main Course', 'Paneer Do Pyaza',
   'Cottage cheese with double-onion masala', 240, true,
   'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=600&q=80&auto=format&fit=crop'),
  ('Sattvik Events', 'Main Course', 'Khichdi',
   'Moong dal & rice comfort bowl', 160, true,
   'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=600&q=80&auto=format&fit=crop'),
  ('Sattvik Events', 'Desserts', 'Kesar Phirni',
   'Saffron rice pudding, terracotta pot', 120, true,
   'https://images.unsplash.com/photo-1589249137304-08b68dc4b019?w=600&q=80&auto=format&fit=crop')
) as v(rest_name, cat_name, name, description, price, is_veg, img)
join r on r.name = v.rest_name
join c on c.name = v.cat_name
where not exists (
  select 1 from public.menu_items mi
  where mi.restaurant_id = r.id and mi.category_id = c.id and mi.name = v.name
);


-- ============================================================================
-- 3. MENU ITEM IMAGES (set image_url by restaurant_name + item_name)
-- ============================================================================

create or replace function public._set_menu_image(
  p_restaurant text,
  p_item text,
  p_url text
) returns void
language plpgsql
as $$
begin
  update public.menu_items mi
     set image_url = p_url
   from public.restaurants r
  where mi.restaurant_id = r.id
    and r.name = p_restaurant
    and mi.name = p_item;
end;
$$;

-- ===== Spice Route Catering ======
select public._set_menu_image('Spice Route Catering', 'Masala Lemonade',
  'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Spice Route Catering', 'Rose Sharbat',
  'https://images.unsplash.com/photo-1546171753-97d7676e4602?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Spice Route Catering', 'Aam Panna',
  'https://images.unsplash.com/photo-1601924994987-69e26d50dc26?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Spice Route Catering', 'Paneer Tikka',
  'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Spice Route Catering', 'Hara Bhara Kebab',
  'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Spice Route Catering', 'Murg Malai Kebab',
  'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Spice Route Catering', 'Mutton Seekh Kebab',
  'https://images.unsplash.com/photo-1633321702518-7feccafb94d5?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Spice Route Catering', 'Dal Makhani',
  'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Spice Route Catering', 'Paneer Butter Masala',
  'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Spice Route Catering', 'Hyderabadi Biryani',
  'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Spice Route Catering', 'Veg Biryani',
  'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Spice Route Catering', 'Butter Naan',
  'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Spice Route Catering', 'Gulab Jamun',
  'https://images.unsplash.com/photo-1601303516361-77e7e2d77eec?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Spice Route Catering', 'Gajar Halwa',
  'https://images.unsplash.com/photo-1625398407937-2fa21d36f11f?w=600&q=80&auto=format&fit=crop');

-- ===== Royal Banquet Kitchen ======
select public._set_menu_image('Royal Banquet Kitchen', 'Coconut Cooler',
  'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Royal Banquet Kitchen', 'Jaljeera Shot',
  'https://images.unsplash.com/photo-1544145945-f90425340c7e?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Royal Banquet Kitchen', 'Galouti Kebab',
  'https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Royal Banquet Kitchen', 'Tandoori Mushroom',
  'https://images.unsplash.com/photo-1625944525903-f58dfa6cf4db?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Royal Banquet Kitchen', 'Kashmiri Rogan Josh',
  'https://images.unsplash.com/photo-1574484284002-952d92456975?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Royal Banquet Kitchen', 'Paneer Lababdar',
  'https://images.unsplash.com/photo-1628294895950-9805252327bc?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Royal Banquet Kitchen', 'Lucknowi Biryani',
  'https://images.unsplash.com/photo-1631515243349-e0cb75fb8d3a?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Royal Banquet Kitchen', 'Jeera Rice',
  'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Royal Banquet Kitchen', 'Rasmalai',
  'https://images.unsplash.com/photo-1589249137304-08b68dc4b019?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Royal Banquet Kitchen', 'Shahi Tukda',
  'https://images.unsplash.com/photo-1630410333262-a51e884dee25?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Royal Banquet Kitchen', 'Pickle & Papad Platter',
  'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Royal Banquet Kitchen', 'Raita',
  'https://images.unsplash.com/photo-1626132647523-66f5bf380027?w=600&q=80&auto=format&fit=crop');

-- ===== Coastal Kitchen ======
select public._set_menu_image('Coastal Kitchen', 'Sol Kadhi',
  'https://images.unsplash.com/photo-1572449043416-55f4685c9bb7?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Coastal Kitchen', 'Prawn Koliwada',
  'https://images.unsplash.com/photo-1625943553852-781c6dd46faa?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Coastal Kitchen', 'Gobi 65',
  'https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Coastal Kitchen', 'Goan Fish Curry',
  'https://images.unsplash.com/photo-1626804475297-41608ea09aeb?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Coastal Kitchen', 'Malabar Paratha',
  'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=600&q=80&auto=format&fit=crop');
select public._set_menu_image('Coastal Kitchen', 'Bebinca',
  'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=600&q=80&auto=format&fit=crop');


-- ============================================================================
-- Verification queries (optional — run separately to confirm)
-- ============================================================================
-- select count(*) from public.restaurants;               -- expect 6
-- select count(*) from public.user_addresses;            -- any
-- select count(*) from public.menu_items where image_url is not null;
