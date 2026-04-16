-- ============================================================================
--  Banquet & Catering — Supabase schema (v1)
--  Run sections sequentially in the Supabase SQL editor.
--  Compatible with Postgres 15 / Supabase.
-- ============================================================================

-- ---------- Extensions ------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";


-- ============================================================================
-- 1. profiles — 1:1 with auth.users, holds role (user | admin).
-- ============================================================================
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  role       text not null default 'user' check (role in ('user','admin')),
  name       text,
  phone      text,
  email      text,
  created_at timestamptz not null default now()
);

-- Helper: is_admin(uuid) — used throughout RLS
create or replace function public.is_admin(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = uid and p.role = 'admin'
  );
$$;

-- Auto-create a profile row on new auth user.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, phone, email)
  values (new.id, new.phone, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- ============================================================================
-- 2. Menu catalog — admin-managed.
-- ============================================================================
create table if not exists public.menu_categories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  sort_order int  not null
);

create table if not exists public.restaurants (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  logo_url         text,
  delivery_charge  numeric(10,2) not null default 0,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now()
);

create table if not exists public.menu_items (
  id            uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  category_id   uuid not null references public.menu_categories(id) on delete restrict,
  name          text not null,
  description   text,
  price         numeric(10,2) not null,
  image_url     text,
  is_veg        boolean not null default true,
  is_available  boolean not null default true,
  created_at    timestamptz not null default now()
);

create index if not exists idx_menu_items_restaurant on public.menu_items(restaurant_id);
create index if not exists idx_menu_items_category   on public.menu_items(category_id);


-- ============================================================================
-- 3. charges_config — single-row pricing table.
-- ============================================================================
create table if not exists public.charges_config (
  id                int primary key default 1 check (id = 1),
  banquet_charge    numeric(10,2) not null default 0,
  buffet_setup      numeric(10,2) not null default 0,
  service_boy_cost  numeric(10,2) not null default 0,
  water_bottle_cost numeric(10,2) not null default 0,
  platform_fee     numeric(10,2) not null default 0,
  gst_percent      numeric(5,2)  not null default 5
);


-- ============================================================================
-- 4. events + orders.
-- ============================================================================
create table if not exists public.events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  event_date  date  not null,
  location    text  not null,
  session     text  not null,
  start_time  time  not null,
  end_time    time  not null,
  guest_count int   not null,
  created_at  timestamptz not null default now()
);
create index if not exists idx_events_user on public.events(user_id);

do $$ begin
  create type order_status as enum ('placed','confirmed','preparing','dispatched','delivered','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type payment_status as enum ('pending','paid','failed','refunded');
exception when duplicate_object then null; end $$;

create table if not exists public.orders (
  id                 uuid primary key default gen_random_uuid(),
  event_id           uuid not null references public.events(id) on delete restrict,
  user_id            uuid not null references auth.users(id) on delete cascade,
  food_cost          numeric(10,2) not null,
  banquet_charge     numeric(10,2) not null,
  delivery_charge    numeric(10,2) not null,
  buffet_setup       numeric(10,2) not null,
  service_boy_cost   numeric(10,2) not null,
  water_bottle_cost  numeric(10,2) not null,
  platform_fee       numeric(10,2) not null,
  subtotal           numeric(12,2) not null,
  gst                numeric(10,2) not null,
  total              numeric(12,2) not null,
  payment_status     payment_status not null default 'pending',
  order_status       order_status not null default 'placed',
  razorpay_order_id  text,
  razorpay_payment_id text,
  created_at         timestamptz not null default now()
);
create index if not exists idx_orders_user on public.orders(user_id);
create index if not exists idx_orders_status on public.orders(order_status);

create table if not exists public.order_items (
  id             uuid primary key default gen_random_uuid(),
  order_id       uuid not null references public.orders(id) on delete cascade,
  menu_item_id   uuid not null references public.menu_items(id) on delete restrict,
  qty            int  not null check (qty > 0),
  price_at_order numeric(10,2) not null
);
create index if not exists idx_order_items_order on public.order_items(order_id);


-- ============================================================================
-- 5. RLS policies.
-- ============================================================================

-- profiles
alter table public.profiles enable row level security;
drop policy if exists "profiles_self_read" on public.profiles;
drop policy if exists "profiles_self_insert" on public.profiles;
drop policy if exists "profiles_self_update" on public.profiles;
drop policy if exists "profiles_admin_read_all" on public.profiles;
create policy "profiles_self_read"
  on public.profiles for select using (auth.uid() = id);
create policy "profiles_self_insert"
  on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_self_update"
  on public.profiles for update using (auth.uid() = id);
create policy "profiles_admin_read_all"
  on public.profiles for select using (public.is_admin(auth.uid()));

-- menu_categories
alter table public.menu_categories enable row level security;
drop policy if exists "menu_categories_read_all" on public.menu_categories;
drop policy if exists "menu_categories_admin_write" on public.menu_categories;
create policy "menu_categories_read_all"
  on public.menu_categories for select using (true);
create policy "menu_categories_admin_write"
  on public.menu_categories for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- restaurants
alter table public.restaurants enable row level security;
drop policy if exists "restaurants_read_all" on public.restaurants;
drop policy if exists "restaurants_admin_write" on public.restaurants;
create policy "restaurants_read_all"
  on public.restaurants for select using (true);
create policy "restaurants_admin_write"
  on public.restaurants for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- menu_items
alter table public.menu_items enable row level security;
drop policy if exists "menu_items_read_all" on public.menu_items;
drop policy if exists "menu_items_admin_write" on public.menu_items;
create policy "menu_items_read_all"
  on public.menu_items for select using (true);
create policy "menu_items_admin_write"
  on public.menu_items for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- charges_config
alter table public.charges_config enable row level security;
drop policy if exists "charges_read_all" on public.charges_config;
drop policy if exists "charges_admin_update" on public.charges_config;
create policy "charges_read_all"
  on public.charges_config for select using (true);
create policy "charges_admin_update"
  on public.charges_config for update
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- events
alter table public.events enable row level security;
drop policy if exists "events_owner_rw" on public.events;
drop policy if exists "events_admin_read" on public.events;
create policy "events_owner_rw"
  on public.events for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "events_admin_read"
  on public.events for select using (public.is_admin(auth.uid()));

-- orders
alter table public.orders enable row level security;
drop policy if exists "orders_owner_read" on public.orders;
drop policy if exists "orders_owner_insert" on public.orders;
drop policy if exists "orders_admin_read" on public.orders;
drop policy if exists "orders_admin_update" on public.orders;
create policy "orders_owner_read"
  on public.orders for select using (auth.uid() = user_id);
create policy "orders_owner_insert"
  on public.orders for insert with check (auth.uid() = user_id);
create policy "orders_admin_read"
  on public.orders for select using (public.is_admin(auth.uid()));
create policy "orders_admin_update"
  on public.orders for update
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- order_items
alter table public.order_items enable row level security;
drop policy if exists "order_items_owner_rw" on public.order_items;
drop policy if exists "order_items_admin_read" on public.order_items;
create policy "order_items_owner_rw"
  on public.order_items for all
  using (
    exists (select 1 from public.orders o
            where o.id = order_id and o.user_id = auth.uid())
  )
  with check (
    exists (select 1 from public.orders o
            where o.id = order_id and o.user_id = auth.uid())
  );
create policy "order_items_admin_read"
  on public.order_items for select using (public.is_admin(auth.uid()));


-- ============================================================================
-- 6. Seed data.
-- ============================================================================
insert into public.charges_config (id, banquet_charge, buffet_setup,
  service_boy_cost, water_bottle_cost, platform_fee, gst_percent)
values (1, 8000, 2500, 3500, 1000, 149, 5)
on conflict (id) do nothing;

insert into public.menu_categories (name, sort_order) values
  ('Welcome Drinks', 1),
  ('Starters',        2),
  ('Main Course',     3),
  ('Desserts',        4),
  ('Additional',      5)
on conflict do nothing;


-- ============================================================================
-- 7. Storage buckets (run in the Supabase dashboard or via the API):
--    - menu-images      (public read)
--    - restaurant-logos (public read)
--    - invoices         (private — signed URLs only)
-- ============================================================================

-- ============================================================================
-- 8. Promoting the first admin:
--    Replace <EMAIL> once the user has signed up once via OTP.
--      update public.profiles set role = 'admin'
--      where id = (select id from auth.users where email = '<EMAIL>');
-- ============================================================================
