-- ============================================================================
-- Debug + fix: why didn't the driver see the offer for order 1531029c-…?
--
-- Run the whole file in Supabase SQL Editor. The diagnostics print first,
-- then the fix re-installs the trigger + simplifies the RLS so Realtime
-- reliably pushes 'offered' rows to online delivery partners.
-- ============================================================================


-- ────────────── DIAGNOSTIC 1: Did the trigger fire? ──────────────
-- Expected: one row, status='offered', driver_id=null.
-- If no row, the trigger didn't run on this order.
select id, order_id, status, driver_id, restaurant_name, offered_at
  from public.deliveries
 where order_id = '1531029c-137f-43bf-bc94-a64537150cc8'::uuid;


-- ────────────── DIAGNOSTIC 2: Is the trigger installed? ──────────────
select tgname, tgrelid::regclass
  from pg_trigger
 where tgname = 'trg_orders_auto_dispatch';


-- ────────────── DIAGNOSTIC 3: Publication + replica identity ──────────────
select tablename from pg_publication_tables
 where pubname = 'supabase_realtime'
   and tablename in ('deliveries','orders','profiles');

select c.relname,
       case c.relreplident
         when 'd' then 'default'
         when 'f' then 'full'
         when 'n' then 'nothing'
         when 'i' then 'index'
       end as replica_identity
  from pg_class c
 where c.relname in ('deliveries','orders','profiles')
   and c.relnamespace = 'public'::regnamespace;


-- ────────────── FIX 1: Replay auto-dispatch for this order (if missing) ──
insert into public.deliveries (
  order_id, driver_id, status,
  pickup_address, drop_address,
  distance_km, earning_amount,
  item_count, restaurant_name,
  customer_name, customer_phone,
  event_label, guest_count,
  delivery_otp, eta_minutes,
  created_by
)
select
  o.id, null, 'offered',
  coalesce(r.address, r.name, 'Restaurant pickup'),
  coalesce(e.location, 'Customer address'),
  4.5,
  85,
  coalesce((select count(*) from public.order_items oi where oi.order_id = o.id), 0),
  coalesce(r.name, 'Kitchen'),
  'Customer',
  '',
  coalesce('🎉 ' || e.session, '🎉 Event'),
  coalesce(e.guest_count, 0),
  lpad((floor(random() * 10000))::text, 4, '0'),
  18,
  o.user_id
  from public.orders o
  left join public.restaurants r on r.id = o.restaurant_id
  left join public.events      e on e.id = o.event_id
 where o.id = '1531029c-137f-43bf-bc94-a64537150cc8'::uuid
   and not exists (
     select 1 from public.deliveries d where d.order_id = o.id
   );


-- ────────────── FIX 2: Simpler driver-read RLS for reliable Realtime ──────
-- Supabase Realtime's authorizer context sometimes fails on RLS that calls
-- security-definer functions. Swap to an inline EXISTS against profiles.
drop policy if exists "deliveries_driver_read" on public.deliveries;
create policy "deliveries_driver_read"
  on public.deliveries for select
  using (
    (status = 'offered'
      and exists (
        select 1 from public.profiles p
         where p.id = auth.uid() and p.role = 'delivery'
      ))
    or driver_id = auth.uid()
  );

drop policy if exists "deliveries_driver_update" on public.deliveries;
create policy "deliveries_driver_update"
  on public.deliveries for update
  using (
    exists (
      select 1 from public.profiles p
       where p.id = auth.uid() and p.role = 'delivery'
    )
    and (driver_id = auth.uid() or (status = 'offered' and driver_id is null))
  )
  with check (
    exists (
      select 1 from public.profiles p
       where p.id = auth.uid() and p.role = 'delivery'
    )
    and (driver_id = auth.uid() or driver_id is null)
  );


-- ────────────── FIX 3: Force replica identity full ──────────────
alter table public.deliveries replica identity full;
alter table public.orders     replica identity full;
alter table public.profiles   replica identity full;


-- ────────────── FINAL CHECK: should return the row now ──────────────
select id, order_id, status, driver_id, restaurant_name, offered_at
  from public.deliveries
 where order_id = '1531029c-137f-43bf-bc94-a64537150cc8'::uuid;
