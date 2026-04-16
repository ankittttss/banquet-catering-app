-- ============================================================================
--  Dawat — Menu item image URLs (quick path)
--  Hand-curated Unsplash CDN URLs. No API key needed — the app's
--  CachedNetworkImage loads them directly. Run after seed_data.sql.
--
--  For the "proper" path (images hosted in your Supabase bucket),
--  run tool/upload_menu_images.mjs instead — it downloads these and uploads
--  them to `menu-images`, then rewrites image_url to the bucket path.
-- ============================================================================

-- Helper: set image_url by (restaurant_name, item_name).
-- Usage:   SELECT _set_menu_image('Spice Route Catering', 'Paneer Tikka',
--                                 'https://images.unsplash.com/photo-XXX');
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
