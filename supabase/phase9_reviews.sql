-- ============================================================================
-- Phase 9 — Restaurant reviews.
--
--   • Adds `public.reviews` — one row per (user, order) for a restaurant.
--   • Adds `orders.restaurant_id` + backfills from order_items join.
--   • Installs a trigger that recomputes `restaurants.rating` +
--     `restaurants.ratings_count` whenever a review is created, updated
--     or deleted.
--
-- Safe to re-run.
-- ============================================================================


-- ============================================================================
-- 1. orders.restaurant_id — link orders to a single restaurant for easy
--    review lookup. Backfilled from the first order_item's menu_item.
-- ============================================================================
alter table public.orders
  add column if not exists restaurant_id uuid
    references public.restaurants(id) on delete set null;

create index if not exists idx_orders_restaurant
  on public.orders(restaurant_id);

update public.orders o
   set restaurant_id = sub.restaurant_id
  from (
    select distinct on (oi.order_id)
           oi.order_id,
           mi.restaurant_id
      from public.order_items oi
      join public.menu_items  mi on mi.id = oi.menu_item_id
     order by oi.order_id, oi.id
  ) sub
 where sub.order_id = o.id
   and o.restaurant_id is null;


-- ============================================================================
-- 2. reviews table.
-- ============================================================================
create table if not exists public.reviews (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  order_id      uuid          references public.orders(id) on delete set null,
  rating        int  not null check (rating between 1 and 5),
  comment       text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (user_id, order_id)
);

create index if not exists idx_reviews_restaurant
  on public.reviews(restaurant_id, created_at desc);
create index if not exists idx_reviews_user
  on public.reviews(user_id, created_at desc);

-- Explicit FK to public.profiles so PostgREST can embed `profiles(name)` on
-- review selects. profiles.id === auth.users.id, so this is safe.
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'reviews_user_profile_fkey'
  ) then
    alter table public.reviews
      add constraint reviews_user_profile_fkey
      foreign key (user_id)
      references public.profiles(id)
      on delete cascade;
  end if;
end $$;


-- ============================================================================
-- 3. Recompute trigger — keep restaurants.rating / ratings_count in sync.
-- ============================================================================
create or replace function public.recompute_restaurant_rating(p_rid uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.restaurants r
     set rating = coalesce((
           select round(avg(rating)::numeric, 1)
             from public.reviews
            where restaurant_id = p_rid
         ), 0),
         ratings_count = (
           select count(*) from public.reviews
            where restaurant_id = p_rid
         )
   where r.id = p_rid;
end $$;

create or replace function public.on_review_change()
returns trigger
language plpgsql
security definer
as $$
begin
  if tg_op = 'DELETE' then
    perform public.recompute_restaurant_rating(old.restaurant_id);
    return old;
  else
    perform public.recompute_restaurant_rating(new.restaurant_id);
    if tg_op = 'UPDATE' and new.restaurant_id <> old.restaurant_id then
      perform public.recompute_restaurant_rating(old.restaurant_id);
    end if;
    return new;
  end if;
end $$;

drop trigger if exists trg_reviews_sync on public.reviews;
create trigger trg_reviews_sync
after insert or update or delete on public.reviews
for each row execute function public.on_review_change();


-- ============================================================================
-- 4. updated_at auto-bump.
-- ============================================================================
create or replace function public.touch_review_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_reviews_touch on public.reviews;
create trigger trg_reviews_touch
before update on public.reviews
for each row execute function public.touch_review_updated_at();


-- ============================================================================
-- 5. RLS.
-- ============================================================================
alter table public.reviews enable row level security;

drop policy if exists "reviews_read_all"     on public.reviews;
drop policy if exists "reviews_insert_self"  on public.reviews;
drop policy if exists "reviews_update_self"  on public.reviews;
drop policy if exists "reviews_delete_self"  on public.reviews;

create policy "reviews_read_all"
  on public.reviews for select using (true);

create policy "reviews_insert_self"
  on public.reviews for insert
  with check (auth.uid() = user_id);

create policy "reviews_update_self"
  on public.reviews for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "reviews_delete_self"
  on public.reviews for delete
  using (auth.uid() = user_id);


-- ============================================================================
-- 6. Seed: keep current hard-coded ratings. New real reviews override them
--    via the trigger on first write.
-- ============================================================================
-- (No-op — we don't seed synthetic reviews; existing rating columns stay
--  as-is until the first genuine review arrives.)


-- ============================================================================
-- 7. Verify (manual).
-- ============================================================================
-- select count(*) from public.reviews;
-- select id, rating, ratings_count from public.restaurants limit 5;
