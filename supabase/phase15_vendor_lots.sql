-- ============================================================================
-- Phase 15 — Multi-restaurant cart (vendor lots) + per-guest quantity.
--
-- Schema change summary:
--   • `order_vendor_lots` — one row per restaurant participating in an order.
--     Status machine lives here (pending → accepted → preparing → ready).
--     Lets a single customer order cover multiple kitchens while each kitchen
--     tracks its own slice independently.
--   • `order_items.vendor_lot_id` — nullable FK so legacy rows keep resolving.
--     Backfilled from the item's menu_item → restaurant link at migration time
--     via a generated lot per legacy order.
--   • `order_items.qty_per_guest` — nullable numeric. When set, the stored
--     `qty` is interpreted as qty-per-guest and billed qty = qty_per_guest *
--     events.guest_count. When null, the row uses legacy absolute-qty pricing.
--
-- Safe to re-run (idempotent).
-- ============================================================================


-- ============================================================================
-- 1. Status enum.
-- ============================================================================
do $$ begin
  create type vendor_lot_status as enum (
    'pending', 'accepted', 'preparing', 'ready_for_pickup',
    'picked_up', 'delivered', 'cancelled'
  );
exception when duplicate_object then null; end $$;


-- ============================================================================
-- 2. order_vendor_lots — authoritative per-vendor slice of an order.
-- ============================================================================
create table if not exists public.order_vendor_lots (
  id             uuid primary key default gen_random_uuid(),
  order_id       uuid not null references public.orders(id)       on delete cascade,
  restaurant_id  uuid not null references public.restaurants(id)  on delete restrict,
  subtotal       numeric(12,2) not null default 0,
  status         vendor_lot_status not null default 'pending',
  accepted_at    timestamptz,
  ready_at       timestamptz,
  picked_up_at   timestamptz,
  delivered_at   timestamptz,
  created_at     timestamptz not null default now(),
  unique (order_id, restaurant_id)
);

create index if not exists idx_lots_order       on public.order_vendor_lots(order_id);
create index if not exists idx_lots_restaurant  on public.order_vendor_lots(restaurant_id);
create index if not exists idx_lots_status      on public.order_vendor_lots(status);


-- ============================================================================
-- 3. order_items — vendor_lot_id (nullable) + qty_per_guest (nullable).
-- ============================================================================
alter table public.order_items
  add column if not exists vendor_lot_id uuid
    references public.order_vendor_lots(id) on delete set null,
  add column if not exists qty_per_guest numeric(6,2);

create index if not exists idx_order_items_lot
  on public.order_items(vendor_lot_id);


-- ============================================================================
-- 4. Backfill — for any existing order_items without a vendor_lot_id, create
--    (or reuse) a lot per (order_id, restaurant_id) pair derived from the
--    item's menu_item → restaurant link.
-- ============================================================================
with pairs as (
  select distinct o.id as order_id, mi.restaurant_id
    from public.orders o
    join public.order_items oi on oi.order_id = o.id
    join public.menu_items  mi on mi.id = oi.menu_item_id
    where oi.vendor_lot_id is null
)
insert into public.order_vendor_lots (order_id, restaurant_id, subtotal, status)
select pairs.order_id, pairs.restaurant_id, 0, 'pending'
  from pairs
on conflict (order_id, restaurant_id) do nothing;

-- Link items to their lot.
-- Note: Postgres forbids JOINs that reference the UPDATE target inside the
-- FROM clause, so we express the multi-table match via comma + WHERE.
update public.order_items oi
   set vendor_lot_id = lots.id
  from public.order_vendor_lots lots,
       public.menu_items        mi
 where oi.vendor_lot_id is null
   and mi.id              = oi.menu_item_id
   and lots.order_id      = oi.order_id
   and lots.restaurant_id = mi.restaurant_id;

-- Recompute lot subtotals from item prices.
update public.order_vendor_lots lots
   set subtotal = coalesce(sub.total, 0)
  from (
    select vendor_lot_id, sum(qty * price_at_order) as total
      from public.order_items
     where vendor_lot_id is not null
     group by vendor_lot_id
  ) sub
 where sub.vendor_lot_id = lots.id;


-- ============================================================================
-- 5. RLS — customers read their own order's lots, admins + the owning
--    restaurant staff read them, admins write status.
-- ============================================================================
alter table public.order_vendor_lots enable row level security;

drop policy if exists "lots_owner_read"      on public.order_vendor_lots;
drop policy if exists "lots_staff_read"      on public.order_vendor_lots;
drop policy if exists "lots_admin_rw"        on public.order_vendor_lots;
drop policy if exists "lots_staff_update"    on public.order_vendor_lots;

-- Customer reads lots belonging to their own orders.
create policy "lots_owner_read"
  on public.order_vendor_lots for select
  using (
    exists (
      select 1 from public.orders o
       where o.id = order_id and o.user_id = auth.uid()
    )
  );

-- Restaurant staff read lots routed to a kitchen they own.
create policy "lots_staff_read"
  on public.order_vendor_lots for select
  using (
    exists (
      select 1 from public.restaurant_staff rs
       where rs.restaurant_id = order_vendor_lots.restaurant_id
         and rs.profile_id = auth.uid()
    )
  );

-- Restaurant staff may update ONLY the status + timestamps of lots they own.
create policy "lots_staff_update"
  on public.order_vendor_lots for update
  using (
    exists (
      select 1 from public.restaurant_staff rs
       where rs.restaurant_id = order_vendor_lots.restaurant_id
         and rs.profile_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.restaurant_staff rs
       where rs.restaurant_id = order_vendor_lots.restaurant_id
         and rs.profile_id = auth.uid()
    )
  );

-- Admins full control.
create policy "lots_admin_rw"
  on public.order_vendor_lots for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));


-- ============================================================================
-- 6. Realtime — restaurant dashboards need lot status pushes.
-- ============================================================================
do $$
begin
  alter publication supabase_realtime add table public.order_vendor_lots;
exception when duplicate_object then null; end $$;

alter table public.order_vendor_lots replica identity full;
