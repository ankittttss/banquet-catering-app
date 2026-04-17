-- ============================================================================
--  Feast Phase 1 — Home screen backend.
--  Idempotent; safe to re-run. Paste into Supabase SQL Editor → Run.
--
--  Adds:
--    1. Restaurant metadata (price_per_plate, delivery ETA, rating, cuisines,
--       tag, hero visuals, min_guests, is_pure_veg)
--    2. event_categories — the 8-tile "What's the occasion?" grid
--    3. collections     — the "Curated for events" horizontal scroll
--    4. favorites       — user ↔ restaurant hearts (synced, with RLS)
--    5. Seed data for event_categories + collections + restaurant metadata
-- ============================================================================


-- ============================================================================
-- 1. RESTAURANT METADATA
-- ============================================================================

alter table public.restaurants
  add column if not exists price_per_plate      numeric(10,2),
  add column if not exists min_guests           int     default 10,
  add column if not exists delivery_min_minutes int,
  add column if not exists delivery_max_minutes int,
  add column if not exists rating               numeric(2,1),
  add column if not exists ratings_count        int     default 0,
  add column if not exists cuisines_display     text,
  add column if not exists hero_bg_hex          text    default '#FFF3E0',
  add column if not exists hero_emoji           text    default '🍽️',
  add column if not exists tag                  text,
  add column if not exists is_pure_veg          boolean default false,
  add column if not exists popularity_score     int     default 0;

update public.restaurants set
  price_per_plate      = 300,
  delivery_min_minutes = 30,
  delivery_max_minutes = 40,
  rating               = 4.5,
  ratings_count        = 12400,
  cuisines_display     = 'Biryani · North Indian · Mughlai',
  hero_bg_hex          = '#FFF3E0',
  hero_emoji           = '🍛',
  tag                  = 'Bestseller',
  min_guests           = 5,
  popularity_score     = 100
 where name = 'Spice Route Catering' and price_per_plate is null;

update public.restaurants set
  price_per_plate      = 250,
  delivery_min_minutes = 45,
  delivery_max_minutes = 60,
  rating               = 4.3,
  ratings_count        = 3200,
  cuisines_display     = 'Multi-cuisine · Buffet · Catering',
  hero_bg_hex          = '#EDE7F6',
  hero_emoji           = '🥘',
  tag                  = 'Event Special',
  min_guests           = 20,
  popularity_score     = 90
 where name = 'Royal Banquet Kitchen' and price_per_plate is null;

update public.restaurants set
  price_per_plate      = 200,
  delivery_min_minutes = 35,
  delivery_max_minutes = 50,
  rating               = 4.7,
  ratings_count        = 8900,
  cuisines_display     = 'South Indian · Thali · Andhra',
  hero_bg_hex          = '#E8F5E9',
  hero_emoji           = '🥥',
  tag                  = 'Pure Veg',
  is_pure_veg          = true,
  min_guests           = 10,
  popularity_score     = 85
 where name = 'Coastal Kitchen' and price_per_plate is null;

update public.restaurants set
  price_per_plate      = 280,
  delivery_min_minutes = 40,
  delivery_max_minutes = 55,
  rating               = 4.4,
  ratings_count        = 2100,
  cuisines_display     = 'Rajasthani · Thali · Traditional',
  hero_bg_hex          = '#FFF8E1',
  hero_emoji           = '🪔',
  tag                  = 'Royal Thali',
  min_guests           = 15,
  popularity_score     = 70
 where name = 'Maharaj Rasoi' and price_per_plate is null;

update public.restaurants set
  price_per_plate      = 320,
  delivery_min_minutes = 40,
  delivery_max_minutes = 55,
  rating               = 4.2,
  ratings_count        = 1800,
  cuisines_display     = 'North Indian · Mughlai · Tandoor',
  hero_bg_hex          = '#FFEBEE',
  hero_emoji           = '🍗',
  tag                  = 'Tandoor Special',
  min_guests           = 15,
  popularity_score     = 65
 where name = 'Delhi Darbar Catering' and price_per_plate is null;

update public.restaurants set
  price_per_plate      = 220,
  delivery_min_minutes = 35,
  delivery_max_minutes = 50,
  rating               = 4.6,
  ratings_count        = 1500,
  cuisines_display     = 'Sattvik · Pure Veg · Jain',
  hero_bg_hex          = '#E8F5E9',
  hero_emoji           = '🪷',
  tag                  = 'Pure Veg',
  is_pure_veg          = true,
  min_guests           = 10,
  popularity_score     = 60
 where name = 'Sattvik Events' and price_per_plate is null;


-- ============================================================================
-- 2. EVENT CATEGORIES — "What's the occasion?" 8-tile grid
-- ============================================================================

create table if not exists public.event_categories (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  name        text not null,
  emoji       text not null,
  icon_name   text not null,          -- Material icon name, e.g. 'cake'
  bg_hex      text not null,          -- tile background tint
  icon_hex    text not null,          -- tile icon color
  sort_order  int  not null default 0,
  is_active   boolean not null default true,
  default_guest_count int default 25,
  default_session     text default 'Dinner',
  created_at  timestamptz not null default now()
);

alter table public.event_categories enable row level security;
drop policy if exists "event_categories_read_all" on public.event_categories;
create policy "event_categories_read_all"
  on public.event_categories for select using (true);
drop policy if exists "event_categories_admin_write" on public.event_categories;
create policy "event_categories_admin_write"
  on public.event_categories for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

insert into public.event_categories
  (slug, name, emoji, icon_name, bg_hex, icon_hex, sort_order,
   default_guest_count, default_session)
values
  ('birthday',    'Birthday',     '🎂', 'cake',             '#FFF1F2', '#E23744', 1, 30,  'Dinner'),
  ('wedding',     'Wedding',      '💖', 'favorite',         '#FCE8F0', '#D63384', 2, 250, 'Dinner'),
  ('corporate',   'Corporate',    '🏢', 'business_center',  '#EBF4FF', '#2B6CB0', 3, 80,  'Lunch'),
  ('house',       'House Party',  '🏠', 'house',            '#FFF8E7', '#E5A100', 4, 25,  'Dinner'),
  ('kitty',       'Kitty Party',  '🎉', 'groups',           '#F3E8FF', '#9B59B6', 5, 20,  'Lunch'),
  ('festival',    'Festival',     '🪔', 'auto_awesome',     '#FFF1F2', '#E23744', 6, 120, 'Dinner'),
  ('anniversary', 'Anniversary',  '💍', 'diamond',          '#EAFAF1', '#1BA672', 7, 60,  'Dinner'),
  ('gettogether', 'Get-together', '🎊', 'celebration',      '#FFF8E7', '#E5A100', 8, 40,  'Dinner')
on conflict (slug) do update set
  name       = excluded.name,
  emoji      = excluded.emoji,
  icon_name  = excluded.icon_name,
  bg_hex     = excluded.bg_hex,
  icon_hex   = excluded.icon_hex,
  sort_order = excluded.sort_order;


-- ============================================================================
-- 3. COLLECTIONS — "Curated for events" horizontal scroll
-- ============================================================================

create table if not exists public.collections (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  name        text not null,
  subtitle    text,                    -- e.g. "28 places"
  emoji       text not null,
  icon_name   text not null,
  bg_hex      text not null,
  icon_hex    text not null,
  sort_order  int  not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

alter table public.collections enable row level security;
drop policy if exists "collections_read_all" on public.collections;
create policy "collections_read_all"
  on public.collections for select using (true);
drop policy if exists "collections_admin_write" on public.collections;
create policy "collections_admin_write"
  on public.collections for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

insert into public.collections
  (slug, name, subtitle, emoji, icon_name, bg_hex, icon_hex, sort_order)
values
  ('platters',  'Party Platters', '28 places', '🍽️', 'set_meal',              '#FFF1F2', '#E23744', 1),
  ('biryani',   'Bulk Biryani',   '15 places', '🍚', 'rice_bowl',             '#FFF8E7', '#E5A100', 2),
  ('sweets',    'Sweet Boxes',    '22 places', '🍬', 'card_giftcard',         '#F3E8FF', '#9B59B6', 3),
  ('live',      'Live Counters',  '12 places', '🔥', 'local_fire_department', '#EAFAF1', '#1BA672', 4)
on conflict (slug) do update set
  name       = excluded.name,
  subtitle   = excluded.subtitle,
  emoji      = excluded.emoji,
  icon_name  = excluded.icon_name,
  bg_hex     = excluded.bg_hex,
  icon_hex   = excluded.icon_hex,
  sort_order = excluded.sort_order;


-- ============================================================================
-- 4. FAVORITES — user ↔ restaurant heart, RLS-owned
-- ============================================================================

create table if not exists public.favorites (
  user_id       uuid not null references auth.users(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  created_at    timestamptz not null default now(),
  primary key (user_id, restaurant_id)
);

create index if not exists idx_favorites_user on public.favorites(user_id);

alter table public.favorites enable row level security;
drop policy if exists "favorites_owner_rw" on public.favorites;
create policy "favorites_owner_rw"
  on public.favorites for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- ============================================================================
-- Verification (optional)
-- ============================================================================
-- select name, price_per_plate, rating, cuisines_display from public.restaurants;
-- select slug, name, sort_order from public.event_categories order by sort_order;
-- select slug, name, subtitle  from public.collections     order by sort_order;
