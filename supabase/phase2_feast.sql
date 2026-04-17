-- ============================================================================
--  Feast Phase 2 — Search + Restaurant Detail + Cart + Checkout backend.
--  Idempotent; safe to re-run. Paste into Supabase SQL Editor → Run.
--
--  Adds:
--    1. restaurant_offers — offer cards at top of restaurant detail screen
--    2. trending_searches — seeded search-chip suggestions on the Search screen
--    3. Seed data
-- ============================================================================


-- ============================================================================
-- 1. RESTAURANT OFFERS
-- ============================================================================

create table if not exists public.restaurant_offers (
  id            uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  title         text not null,
  subtitle      text,
  code          text,
  accent_hex    text default '#2B6CB0',
  bg_hex        text default '#EBF4FF',
  is_active     boolean not null default true,
  sort_order    int not null default 0,
  valid_until   timestamptz,
  created_at    timestamptz not null default now()
);

create index if not exists idx_offers_restaurant
  on public.restaurant_offers(restaurant_id) where is_active;

alter table public.restaurant_offers enable row level security;
drop policy if exists "offers_read_all"  on public.restaurant_offers;
drop policy if exists "offers_admin_write" on public.restaurant_offers;
create policy "offers_read_all"
  on public.restaurant_offers for select using (true);
create policy "offers_admin_write"
  on public.restaurant_offers for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- Seed an offer per restaurant so every detail page shows something.
insert into public.restaurant_offers
  (restaurant_id, title, subtitle, code, accent_hex, bg_hex, sort_order)
select r.id,
       '50% OFF up to ₹100',
       'Use code FEAST50 · Above ₹299',
       'FEAST50',
       '#2B6CB0',
       '#EBF4FF',
       1
  from public.restaurants r
 where not exists (
   select 1 from public.restaurant_offers o
    where o.restaurant_id = r.id and o.code = 'FEAST50'
 );

insert into public.restaurant_offers
  (restaurant_id, title, subtitle, code, accent_hex, bg_hex, sort_order)
select r.id,
       'Free delivery on 50+ plates',
       'No code needed · Auto-applied',
       null,
       '#1BA672',
       '#EAFAF1',
       2
  from public.restaurants r
 where not exists (
   select 1 from public.restaurant_offers o
    where o.restaurant_id = r.id and o.sort_order = 2
 );


-- ============================================================================
-- 2. TRENDING SEARCHES
-- ============================================================================

create table if not exists public.trending_searches (
  id         uuid primary key default gen_random_uuid(),
  label      text unique not null,
  emoji      text,
  sort_order int not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.trending_searches enable row level security;
drop policy if exists "trending_read_all"  on public.trending_searches;
drop policy if exists "trending_admin_write" on public.trending_searches;
create policy "trending_read_all"
  on public.trending_searches for select using (true);
create policy "trending_admin_write"
  on public.trending_searches for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

insert into public.trending_searches (label, emoji, sort_order) values
  ('Biryani',          '🍛', 1),
  ('Birthday Cakes',   '🎂', 2),
  ('Veg Platters',     '🥗', 3),
  ('North Indian',     '🍲', 4),
  ('Dessert Boxes',    '🍰', 5),
  ('South Indian',     '🥥', 6),
  ('Pizza for Groups', '🍕', 7),
  ('Cupcakes',         '🧁', 8)
on conflict (label) do update set
  emoji = excluded.emoji,
  sort_order = excluded.sort_order;


-- ============================================================================
-- Verification (optional)
-- ============================================================================
-- select r.name, o.title from public.restaurant_offers o
--   join public.restaurants r on r.id = o.restaurant_id
--  order by r.name, o.sort_order;
-- select label from public.trending_searches order by sort_order;
