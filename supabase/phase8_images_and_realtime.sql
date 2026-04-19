-- ============================================================================
-- Phase 8 — realtime for notifications + stock images for restaurants & menus.
--
--   • Adds `public.notifications` to the `supabase_realtime` publication so
--     the in-app notifications screen's stream no longer times out.
--   • Assigns Unsplash stock photos to `restaurants.logo_url` based on
--     cuisine, and to `menu_items.image_url` based on item name.
--
-- Safe to re-run — only touches rows where the column is still NULL.
-- ============================================================================


-- ============================================================================
-- 1. Realtime publication — add notifications.
-- ============================================================================
do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null; -- already in the publication
end $$;


-- ============================================================================
-- 2. Restaurant logos — stock photo per cuisine keyword.
-- ============================================================================
update public.restaurants
   set logo_url = case
     when cuisines_display ilike '%biryani%' or cuisines_display ilike '%tandoor%'
       then 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800&q=80&auto=format&fit=crop'
     when cuisines_display ilike '%south%' or cuisines_display ilike '%thali%'
       then 'https://images.unsplash.com/photo-1600891964599-f61ba0e24092?w=800&q=80&auto=format&fit=crop'
     when cuisines_display ilike '%chinese%' or cuisines_display ilike '%noodle%'
       then 'https://images.unsplash.com/photo-1552611052-33e04de081de?w=800&q=80&auto=format&fit=crop'
     when cuisines_display ilike '%pure veg%' or cuisines_display ilike '%sattvik%' or cuisines_display ilike '%jain%'
       then 'https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=800&q=80&auto=format&fit=crop'
     when cuisines_display ilike '%coastal%' or cuisines_display ilike '%seafood%'
       then 'https://images.unsplash.com/photo-1626804475297-41608ea09aeb?w=800&q=80&auto=format&fit=crop'
     when cuisines_display ilike '%rajasthani%' or cuisines_display ilike '%thali%'
       then 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=800&q=80&auto=format&fit=crop'
     when cuisines_display ilike '%street%' or cuisines_display ilike '%chaat%'
       then 'https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=800&q=80&auto=format&fit=crop'
     when cuisines_display ilike '%continental%' or cuisines_display ilike '%dessert%'
       then 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&q=80&auto=format&fit=crop'
     when cuisines_display ilike '%multi%' or cuisines_display ilike '%buffet%'
       then 'https://images.unsplash.com/photo-1546241072-48010ad2862c?w=800&q=80&auto=format&fit=crop'
     else
       'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&q=80&auto=format&fit=crop' -- generic North Indian
   end
 where logo_url is null;


-- ============================================================================
-- 3. Menu item photos — Unsplash URL per item name (matches the generator
--    template bank + the legacy menu_images.sql list). Safe to re-run.
-- ============================================================================
update public.menu_items
   set image_url = v.url
  from (values
    -- Welcome Drinks
    ('Masala Lemonade',       'https://images.unsplash.com/photo-1556679343-c7306c1976bc'),
    ('Rose Sharbat',          'https://images.unsplash.com/photo-1546171753-97d7676e4602'),
    ('Aam Panna',             'https://images.unsplash.com/photo-1601924994987-69e26d50dc26'),
    ('Jaljeera',              'https://images.unsplash.com/photo-1544145945-f90425340c7e'),
    ('Buttermilk (Chaas)',    'https://images.unsplash.com/photo-1600271886742-f049cd451bba'),
    ('Sol Kadhi',             'https://images.unsplash.com/photo-1572449043416-55f4685c9bb7'),
    ('Filter Coffee',         'https://images.unsplash.com/photo-1559305616-3f99cd43e353'),
    ('Masala Chai',           'https://images.unsplash.com/photo-1571934811356-5cc061b6821f'),
    ('Thandai',               'https://images.unsplash.com/photo-1546171753-97d7676e4602'),

    -- Starters (veg)
    ('Paneer Tikka',          'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8'),
    ('Hara Bhara Kebab',      'https://images.unsplash.com/photo-1601050690597-df0568f70950'),
    ('Veg Manchurian Dry',    'https://images.unsplash.com/photo-1552611052-33e04de081de'),
    ('Crispy Corn',           'https://images.unsplash.com/photo-1606491956689-2ea866880c84'),
    ('Gobi 65',               'https://images.unsplash.com/photo-1606491956689-2ea866880c84'),
    ('Dahi Kebab',            'https://images.unsplash.com/photo-1601050690597-df0568f70950'),
    ('Samosa Chaat',          'https://images.unsplash.com/photo-1601050690597-df0568f70950'),
    -- Starters (non-veg)
    ('Chicken Tikka',         'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0'),
    ('Murg Malai Kebab',      'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0'),
    ('Mutton Seekh Kebab',    'https://images.unsplash.com/photo-1633321702518-7feccafb94d5'),
    ('Tandoori Prawns',       'https://images.unsplash.com/photo-1625943553852-781c6dd46faa'),
    ('Fish Amritsari',        'https://images.unsplash.com/photo-1626804475297-41608ea09aeb'),
    ('Chilli Chicken Dry',    'https://images.unsplash.com/photo-1552611052-33e04de081de'),

    -- Main Course (veg)
    ('Dal Makhani',                   'https://images.unsplash.com/photo-1585937421612-70a008356fbe'),
    ('Paneer Butter Masala',          'https://images.unsplash.com/photo-1631452180519-c014fe946bc7'),
    ('Kadai Paneer',                  'https://images.unsplash.com/photo-1628294895950-9805252327bc'),
    ('Aloo Gobi',                     'https://images.unsplash.com/photo-1606491956689-2ea866880c84'),
    ('Chole Bhature',                 'https://images.unsplash.com/photo-1626132647523-66f5bf380027'),
    ('Veg Biryani',                   'https://images.unsplash.com/photo-1596797038530-2c107229654b'),
    ('Hyderabadi Veg Dum Biryani',    'https://images.unsplash.com/photo-1596797038530-2c107229654b'),
    ('Mushroom Masala',               'https://images.unsplash.com/photo-1625944525903-f58dfa6cf4db'),
    ('South Indian Thali',            'https://images.unsplash.com/photo-1600891964599-f61ba0e24092'),
    ('Idli Sambhar',                  'https://images.unsplash.com/photo-1589301760014-d929f3979dbc'),
    ('Masala Dosa',                   'https://images.unsplash.com/photo-1668236543090-82eba5ee5976'),
    ('Rajma Chawal',                  'https://images.unsplash.com/photo-1585937421612-70a008356fbe'),
    ('Dal Baati Churma',              'https://images.unsplash.com/photo-1585937421612-70a008356fbe'),
    ('Gatte Ki Sabzi',                'https://images.unsplash.com/photo-1631452180519-c014fe946bc7'),
    ('Veg Hakka Noodles',             'https://images.unsplash.com/photo-1552611052-33e04de081de'),
    ('Veg Fried Rice',                'https://images.unsplash.com/photo-1596797038530-2c107229654b'),
    -- Main Course (non-veg)
    ('Butter Chicken',                'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398'),
    ('Chicken Biryani',               'https://images.unsplash.com/photo-1589302168068-964664d93dc0'),
    ('Mutton Rogan Josh',             'https://images.unsplash.com/photo-1574484284002-952d92456975'),
    ('Andhra Chicken Curry',          'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398'),
    ('Goan Fish Curry',               'https://images.unsplash.com/photo-1626804475297-41608ea09aeb'),
    ('Laal Maas',                     'https://images.unsplash.com/photo-1574484284002-952d92456975'),

    -- Desserts
    ('Gulab Jamun',                   'https://images.unsplash.com/photo-1601303516361-77e7e2d77eec'),
    ('Rasmalai',                      'https://images.unsplash.com/photo-1589249137304-08b68dc4b019'),
    ('Gajar Halwa',                   'https://images.unsplash.com/photo-1625398407937-2fa21d36f11f'),
    ('Kulfi Falooda',                 'https://images.unsplash.com/photo-1625398407937-2fa21d36f11f'),
    ('Phirni',                        'https://images.unsplash.com/photo-1589249137304-08b68dc4b019'),
    ('Double Ka Meetha',              'https://images.unsplash.com/photo-1630410333262-a51e884dee25'),
    ('Payasam',                       'https://images.unsplash.com/photo-1589249137304-08b68dc4b019'),
    ('Ghewar',                        'https://images.unsplash.com/photo-1601303516361-77e7e2d77eec'),
    ('Moong Dal Halwa',               'https://images.unsplash.com/photo-1625398407937-2fa21d36f11f'),

    -- Additional
    ('Pickle & Papad Platter',        'https://images.unsplash.com/photo-1565557623262-b51c2513a641'),
    ('Raita',                         'https://images.unsplash.com/photo-1626132647523-66f5bf380027'),
    ('Butter Naan (Set of 2)',        'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46'),
    ('Lachha Paratha (2)',            'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46'),
    ('Boondi Raita',                  'https://images.unsplash.com/photo-1626132647523-66f5bf380027'),
    ('Green Salad',                   'https://images.unsplash.com/photo-1512621776951-a57141f2eefd'),
    ('Jeera Rice',                    'https://images.unsplash.com/photo-1596797038530-2c107229654b'),
    ('Steamed Rice',                  'https://images.unsplash.com/photo-1596797038530-2c107229654b')
  ) as v(name, url)
 where menu_items.name = v.name
   and menu_items.image_url is null;

-- Append query-string params (width/quality) for every new URL.
update public.menu_items
   set image_url = image_url || '?w=800&q=80&auto=format&fit=crop'
 where image_url like 'https://images.unsplash.com/%'
   and image_url not like '%?%';


-- ============================================================================
-- 4. Verify
-- ============================================================================
-- select count(*) filter (where logo_url is not null) as with_logo,
--        count(*) as total_restaurants
--   from public.restaurants;
-- select count(*) filter (where image_url is not null) as with_image,
--        count(*) as total_items
--   from public.menu_items;
