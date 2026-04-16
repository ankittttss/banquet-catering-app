-- ============================================================================
--  Dawat — additional restaurants + logo URLs
--  Run once in the Supabase SQL editor after seed_data.sql.
-- ============================================================================

-- Add logo URLs to the originally seeded 3
update public.restaurants set logo_url =
  'https://images.unsplash.com/photo-1546241072-48010ad2862c?w=400&q=80&auto=format&fit=crop'
  where name = 'Spice Route Catering';
update public.restaurants set logo_url =
  'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&q=80&auto=format&fit=crop'
  where name = 'Royal Banquet Kitchen';
update public.restaurants set logo_url =
  'https://images.unsplash.com/photo-1595329083003-47e40ec25e05?w=400&q=80&auto=format&fit=crop'
  where name = 'Coastal Kitchen';

-- Three more restaurants so the "Popular" carousel feels populated.
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

-- Menu items for the 3 new restaurants (a few each so the carousel cards
-- look real and orders can be placed against them).
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
