-- ============================================================================
--  Banquet & Catering — sample menu seed
--  Run this ONCE in the Supabase SQL editor after schema.sql.
--  Safe to re-run: uses WHERE NOT EXISTS gates.
-- ============================================================================

-- Restaurants ---------------------------------------------------------------
insert into public.restaurants (name, delivery_charge, is_active)
select 'Spice Route Catering', 1200, true
where not exists (
  select 1 from public.restaurants where name = 'Spice Route Catering'
);

insert into public.restaurants (name, delivery_charge, is_active)
select 'Royal Banquet Kitchen', 1500, true
where not exists (
  select 1 from public.restaurants where name = 'Royal Banquet Kitchen'
);

insert into public.restaurants (name, delivery_charge, is_active)
select 'Coastal Kitchen', 1400, true
where not exists (
  select 1 from public.restaurants where name = 'Coastal Kitchen'
);

-- Menu items ---------------------------------------------------------------
-- Uses lookups by restaurant name + category name so IDs don't matter.
with r as (
  select id, name from public.restaurants
),
c as (
  select id, name from public.menu_categories
)

insert into public.menu_items
  (restaurant_id, category_id, name, description, price, is_veg, is_available)
select r.id, c.id, v.name, v.description, v.price, v.is_veg, true
from (values
  -- ===== Spice Route Catering =====
  ('Spice Route Catering', 'Welcome Drinks', 'Masala Lemonade',
   'Fresh lime with roasted cumin and black salt', 80, true),
  ('Spice Route Catering', 'Welcome Drinks', 'Rose Sharbat',
   'Chilled rose milk with pistachios', 90, true),
  ('Spice Route Catering', 'Welcome Drinks', 'Aam Panna',
   'Raw mango cooler, served seasonally', 85, true),

  ('Spice Route Catering', 'Starters', 'Paneer Tikka',
   'Marinated cottage cheese, charred in tandoor', 220, true),
  ('Spice Route Catering', 'Starters', 'Hara Bhara Kebab',
   'Spinach, peas & potato patties', 180, true),
  ('Spice Route Catering', 'Starters', 'Murg Malai Kebab',
   'Cream-marinated chicken, mild spices', 260, false),
  ('Spice Route Catering', 'Starters', 'Mutton Seekh Kebab',
   'Minced lamb skewers, smoked', 320, false),

  ('Spice Route Catering', 'Main Course', 'Dal Makhani',
   'Slow-cooked black lentils, butter & cream', 180, true),
  ('Spice Route Catering', 'Main Course', 'Paneer Butter Masala',
   'Cottage cheese in tomato-cashew gravy', 220, true),
  ('Spice Route Catering', 'Main Course', 'Hyderabadi Biryani',
   'Basmati rice with dum-cooked chicken', 240, false),
  ('Spice Route Catering', 'Main Course', 'Veg Biryani',
   'Aromatic rice with seasonal vegetables', 200, true),
  ('Spice Route Catering', 'Main Course', 'Butter Naan',
   'Clay-oven flatbread, brushed with ghee', 40, true),

  ('Spice Route Catering', 'Desserts', 'Gulab Jamun',
   'Warm milk dumplings in cardamom syrup', 90, true),
  ('Spice Route Catering', 'Desserts', 'Gajar Halwa',
   'Carrot pudding with nuts', 110, true),

  -- ===== Royal Banquet Kitchen =====
  ('Royal Banquet Kitchen', 'Welcome Drinks', 'Coconut Cooler',
   'Tender coconut with mint', 100, true),
  ('Royal Banquet Kitchen', 'Welcome Drinks', 'Jaljeera Shot',
   'Cumin-mint digestive, spiced', 70, true),

  ('Royal Banquet Kitchen', 'Starters', 'Galouti Kebab',
   'Melt-in-mouth Lucknowi kebabs', 340, false),
  ('Royal Banquet Kitchen', 'Starters', 'Tandoori Mushroom',
   'Stuffed button mushrooms, smoked', 230, true),

  ('Royal Banquet Kitchen', 'Main Course', 'Kashmiri Rogan Josh',
   'Slow-braised lamb in red spice gravy', 320, false),
  ('Royal Banquet Kitchen', 'Main Course', 'Paneer Lababdar',
   'Cottage cheese, onion-tomato masala', 230, true),
  ('Royal Banquet Kitchen', 'Main Course', 'Lucknowi Biryani',
   'Fragrant awadhi biryani, with mutton', 310, false),
  ('Royal Banquet Kitchen', 'Main Course', 'Jeera Rice',
   'Basmati tempered with cumin', 90, true),

  ('Royal Banquet Kitchen', 'Desserts', 'Rasmalai',
   'Saffron-soaked cottage cheese discs', 110, true),
  ('Royal Banquet Kitchen', 'Desserts', 'Shahi Tukda',
   'Saffron-milk bread with pistachios', 140, true),

  ('Royal Banquet Kitchen', 'Additional', 'Pickle & Papad Platter',
   'Assorted pickles and crispy papads', 60, true),
  ('Royal Banquet Kitchen', 'Additional', 'Raita',
   'Boondi or mixed vegetable raita', 70, true),

  -- ===== Coastal Kitchen =====
  ('Coastal Kitchen', 'Welcome Drinks', 'Sol Kadhi',
   'Konkan kokum & coconut cooler', 95, true),

  ('Coastal Kitchen', 'Starters', 'Prawn Koliwada',
   'Fried prawns with gunpowder spice', 320, false),
  ('Coastal Kitchen', 'Starters', 'Gobi 65',
   'Crisp-fried cauliflower, chilli-garlic', 190, true),

  ('Coastal Kitchen', 'Main Course', 'Goan Fish Curry',
   'Pomfret in coconut-tamarind curry', 340, false),
  ('Coastal Kitchen', 'Main Course', 'Malabar Paratha',
   'Flaky layered Kerala flatbread', 50, true),

  ('Coastal Kitchen', 'Desserts', 'Bebinca',
   'Goan 7-layer coconut cake', 160, true)
) as v(rest_name, cat_name, name, description, price, is_veg)
join r on r.name = v.rest_name
join c on c.name = v.cat_name
where not exists (
  select 1 from public.menu_items mi
  where mi.restaurant_id = r.id
    and mi.category_id = c.id
    and mi.name = v.name
);
